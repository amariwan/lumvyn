import Foundation
import OSLog

actor RemoteDeletionQueue {
    struct Entry: Codable, Equatable, Identifiable {
        let localId: String
        let host: String
        let sharePath: String
        let remotePath: String
        var attempts: Int
        var nextTry: Date?
        let createdAt: Date

        var id: String { "\(localId)-\(remotePath)" }
    }

    private let logger = Logger(subsystem: "com.lumvyn.app", category: "DeletionQueue")
    private var queue: [Entry] = []
    private let fileURL: URL
    private var isLoaded = false

    init(fileName: String = "remote-deletion-queue.json") {
        let fileManager = FileManager.default
        let appSupport =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        let dir = appSupport.appendingPathComponent("lumvyn", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(fileName)
    }

    private func ensureLoaded() async {
        guard !isLoaded else { return }
        defer { isLoaded = true }

        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            let fileURLCopy = fileURL
            let detached = Task.detached(priority: .utility) { () -> [Entry] in
                let data = try Data(contentsOf: fileURLCopy)
                return try JSONDecoder().decode([Entry].self, from: data)
            }
            let decoded = try await detached.value
            self.queue = decoded
        } catch {
            logger.error("Failed to load queue: \(error.localizedDescription)")
        }
    }

    func enqueue(localId: String, host: String, sharePath: String, remotePath: String) async {
        await ensureLoaded()

        let newEntry = Entry(
            localId: localId, host: host, sharePath: sharePath, remotePath: remotePath, attempts: 0,
            nextTry: nil, createdAt: Date())

        guard !queue.contains(where: { $0.id == newEntry.id }) else { return }

        queue.append(newEntry)
        persistToDisk()
    }

    func processPending(
        smbClient: SMBClientProtocol, credentials: SMBCredentials?, remoteIndex: RemoteIndexStore?
    ) async -> (deleted: Int, failed: Int) {
        await ensureLoaded()
        guard !queue.isEmpty else { return (0, 0) }

        var deletedCount = 0
        var failedCount = 0
        let now = Date()

        var updatedQueue = queue

        for (index, entry) in updatedQueue.enumerated().reversed() {
            if let next = entry.nextTry, next > now { continue }

            do {
                try await smbClient.deleteRemoteItem(
                    host: entry.host,
                    sharePath: entry.sharePath,
                    remotePath: entry.remotePath,
                    credentials: credentials
                )

                updatedQueue.remove(at: index)
                try? await remoteIndex?.removeMapping(localId: entry.localId)
                deletedCount += 1

            } catch {
                logger.warning(
                    "Deletion failed for \(entry.remotePath): \(error.localizedDescription)")

                var modifiedEntry = entry
                modifiedEntry.attempts += 1
                modifiedEntry.nextTry = calculateNextRetry(for: modifiedEntry.attempts)
                updatedQueue[index] = modifiedEntry
                failedCount += 1
            }
        }

        self.queue = updatedQueue
        persistToDisk()
        return (deletedCount, failedCount)
    }

    func clearAll() async {
        await ensureLoaded()
        queue.removeAll()
        persistToDisk()
    }

    // Returns the number of pending entries in the queue.
    func pendingCount() async -> Int {
        await ensureLoaded()
        return queue.count
    }

    // MARK: - Private Helpers

    private let retryBaseDelaySeconds: TimeInterval = 60.0
    private let retryMaxDelaySeconds: TimeInterval = 3600.0

    private func calculateNextRetry(for attempts: Int) -> Date {
        let delay = min(pow(2.0, Double(attempts)) * retryBaseDelaySeconds, retryMaxDelaySeconds)
        return Date().addingTimeInterval(delay)
    }

    private func persistToDisk() {
        let snapshot = queue
        let url = fileURL

        Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: [.atomic])
            } catch {
                await self.logPersistenceError(error)
            }
        }
    }

    private func logPersistenceError(_ error: Error) {
        logger.error("Persistence error: \(error.localizedDescription)")
    }
}
