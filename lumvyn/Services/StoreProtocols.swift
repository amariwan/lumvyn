import Foundation

// MARK: - Protocols

protocol RemoteIndexStoreProtocol: AnyObject {
    typealias Entry = RemoteIndexStore.Entry

    func fetchAllMappings() async -> [String: Entry]
    func mapping(for localId: String) async -> Entry?
    func saveMapping(
        localId: String,
        host: String,
        sharePath: String,
        remotePath: String,
        fingerprint: String?
    ) async
    func removeMapping(localId: String) async
}

protocol RemoteDeletionQueueProtocol: AnyObject {
    func enqueue(localId: String, host: String, sharePath: String, remotePath: String) async
    func pendingCount() async -> Int
    func clearAll() async
}

protocol NetworkMonitorProtocol: AnyObject {
    func isWifiConnected() async -> Bool
}

// MARK: - Adapters

final class RemoteIndexStoreAdapter: RemoteIndexStoreProtocol {
    private let store: RemoteIndexStore

    init(store: RemoteIndexStore) {
        self.store = store
    }

    func fetchAllMappings() async -> [String: Entry] {
        await store.allMappings()
    }

    func mapping(for localId: String) async -> Entry? {
        await store.mapping(for: localId)
    }

    func saveMapping(
        localId: String,
        host: String,
        sharePath: String,
        remotePath: String,
        fingerprint: String?
    ) async {
        await store.saveMapping(
            localId: localId,
            host: host,
            sharePath: sharePath,
            remotePath: remotePath,
            fingerprint: fingerprint
        )
    }

    func removeMapping(localId: String) async {
        await store.removeMapping(localId: localId)
    }
}

final class RemoteDeletionQueueAdapter: RemoteDeletionQueueProtocol {
    private let queue: RemoteDeletionQueue

    init(queue: RemoteDeletionQueue) {
        self.queue = queue
    }

    func enqueue(localId: String, host: String, sharePath: String, remotePath: String) async {
        await queue.enqueue(localId: localId, host: host, sharePath: sharePath, remotePath: remotePath)
    }

    func pendingCount() async -> Int {
        await queue.pendingCount()
    }

    func clearAll() async {
        await queue.clearAll()
    }
}

final class NetworkMonitorAdapter: NetworkMonitorProtocol {
    private let monitor: NetworkMonitor

    init(monitor: NetworkMonitor) {
        self.monitor = monitor
    }

    func isWifiConnected() async -> Bool {
        await MainActor.run { monitor.isWifiConnected }
    }
}
