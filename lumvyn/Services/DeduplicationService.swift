import CryptoKit
import Foundation
import Photos
import os

private let dedupLogger = Logger(subsystem: "tasio.lumvyn", category: "DeduplicationService")

public enum DeduplicationError: LocalizedError {
    case noResource
    case hashingFailed

    public var errorDescription: String? {
        switch self {
        case .noResource:
            return NSLocalizedString("Keine Asset-Ressource zum Hashen gefunden.", comment: "")
        case .hashingFailed:
            return NSLocalizedString("Hashing des Assets fehlgeschlagen.", comment: "")
        }
    }
}

public actor DeduplicationService {
    private let storageURL: URL
    private var knownFingerprints: Set<String> = []

    private var isLoaded = false
    private var loadTask: Task<Void, Never>?
    private let persistQueue = DispatchQueue(label: "tasio.lumvyn.dedup.persist", qos: .utility)

    public init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let caches =
                FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageURL = caches.appendingPathComponent("dedup.json")
        }
    }

    private func ensureLoaded() async {
        if isLoaded { return }

        if let task = loadTask {
            await task.value
            return
        }

        let detached = Task.detached { () -> Set<String> in
            guard FileManager.default.fileExists(atPath: storageURL.path) else { return Set<String>() }
            do {
                let data = try Data(contentsOf: storageURL)
                let array = try JSONDecoder().decode([String].self, from: data)
                return Set(array)
            } catch {
                dedupLogger.error("Dedup load error: \(error.localizedDescription)")
                return Set<String>()
            }
        }

        let task = Task {
            defer { isLoaded = true }
            let result = await detached.value
            self.knownFingerprints = result
        }

        loadTask = task
        await task.value
        loadTask = nil
    }

    public func contains(_ fingerprint: String) async -> Bool {
        await ensureLoaded()
        return knownFingerprints.contains(fingerprint)
    }

    public func markUploaded(fingerprint: String) async {
        await ensureLoaded()

        let (inserted, _) = knownFingerprints.insert(fingerprint)
        if inserted {
            persistKnownFingerprints()
        }
    }

    private func persistKnownFingerprints() {
        let snapshot = knownFingerprints.sorted()
        let storageCopy = storageURL

        persistQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: storageCopy, options: [.atomic])
            } catch {
                dedupLogger.error("Dedup persist error: \(error.localizedDescription)")
            }
        }
    }

    public func fingerprint(for asset: PHAsset) async throws -> String {
        guard let resource = PHAssetResource.assetResources(for: asset).first else {
            throw DeduplicationError.noResource
        }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString)_\(resource.originalFilename)")
        try? FileManager.default.removeItem(at: tmpURL)

        let resourceOptions = PHAssetResourceRequestOptions()
        resourceOptions.isNetworkAccessAllowed = true

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(
                for: resource, toFile: tmpURL, options: resourceOptions
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return try await Task.detached(priority: .utility) {
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            guard let stream = InputStream(url: tmpURL) else {
                throw DeduplicationError.hashingFailed
            }

            stream.open()
            defer { stream.close() }

            var context = SHA256()
            let bufferSize = 64 * 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read < 0 { throw DeduplicationError.hashingFailed }
                if read == 0 { break }

                context.update(data: Data(bytes: buffer, count: read))
            }

            return context.finalize()
                .map { String(format: "%02x", $0) }
                .joined()
        }.value
    }
}
