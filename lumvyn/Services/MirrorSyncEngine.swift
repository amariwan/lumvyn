import Foundation
import Photos
import os

// MARK: - Result

struct MirrorSyncResult: Sendable {
    var enqueuedDeletions: Int = 0
    var safetyAborted: Bool = false
    var abortReason: String? = nil
    var skippedNetworkUnavailable: Bool = false

    static let empty = MirrorSyncResult()
}

// MARK: - Engine

actor MirrorSyncEngine {
    static let minLocalAssetCount = 5
    static let maxOrphanFraction: Double = 0.90
    static let absoluteSafetyThreshold = 500

    private let logger = Logger(subsystem: "tasio.lumvyn", category: "MirrorSyncEngine")

    private enum DiffOutcome {
        case inSync
        case orphaned(Set<String>)
        case aborted(reason: String)
    }

    // MARK: - Local Fetch

    private func fetchLocalIdentifiers() async -> Set<String> {
        await Task.detached(priority: .utility) {
            let options = PHFetchOptions()
            options.includeHiddenAssets = true
            options.includeAllBurstAssets = false

            let result = PHAsset.fetchAssets(with: options)
            var ids = Set<String>()
            ids.reserveCapacity(result.count)

            result.enumerateObjects { asset, _, _ in
                ids.insert(asset.localIdentifier)
            }

            return ids
        }.value
    }

    // MARK: - Diff

    private func computeDiff(mappings: [String: RemoteIndexStore.Entry]) async -> DiffOutcome {
        let localIds = await fetchLocalIdentifiers()

        guard localIds.count >= Self.minLocalAssetCount else {
            let reason = "Local library has only \(localIds.count) assets – aborting."
            logger.warning("\(reason)")
            return .aborted(reason: reason)
        }

        let orphaned = Set(mappings.keys).subtracting(localIds)

        if orphaned.isEmpty {
            logger.info("Mirror diff: no orphaned items.")
            return .inSync
        }

        let total = mappings.count
        let orphanCount = orphaned.count
        let fraction = Double(orphanCount) / Double(total)

        if orphanCount >= Self.absoluteSafetyThreshold || fraction >= Self.maxOrphanFraction {
            let reason = "Safety threshold exceeded: \(orphanCount)/\(total) (\(Int(fraction * 100))%)"
            logger.warning("\(reason)")
            return .aborted(reason: reason)
        }

        logger.info("Mirror diff: \(orphanCount) orphan(s) out of \(total).")
        return .orphaned(orphaned)
    }

    // MARK: - Public API

    func runSync(
        remoteIndex: RemoteIndexStore,
        deletionQueue: RemoteDeletionQueue,
        wifiOnly: Bool,
        networkMonitor: NetworkMonitor
    ) async -> MirrorSyncResult {
        await runSync(
            using: RemoteIndexStoreAdapter(store: remoteIndex),
            deletionQueue: RemoteDeletionQueueAdapter(queue: deletionQueue),
            wifiOnly: wifiOnly,
            networkMonitor: NetworkMonitorAdapter(monitor: networkMonitor)
        )
    }

    // MARK: - Core Logic

    private func runSync(
        using remoteIndex: any RemoteIndexStoreProtocol,
        deletionQueue: any RemoteDeletionQueueProtocol,
        wifiOnly: Bool,
        networkMonitor: any NetworkMonitorProtocol
    ) async -> MirrorSyncResult {

        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            logger.warning("Photo access not authorised – skipping.")
            return .empty
        }

        if wifiOnly {
            let wifiConnected = await networkMonitor.isWifiConnected()
            guard wifiConnected else {
                logger.info("Skipped: Wi-Fi-only active.")
                return MirrorSyncResult(skippedNetworkUnavailable: true)
            }
        }

        let mappings = await remoteIndex.fetchAllMappings()
        guard !mappings.isEmpty else { return .empty }

        switch await computeDiff(mappings: mappings) {
        case .inSync:
            logger.info("Already in sync.")
            return .empty

        case .aborted(let reason):
            return MirrorSyncResult(safetyAborted: true, abortReason: reason)

        case .orphaned(let orphanedIds):
            var enqueued = 0

            for remoteId in orphanedIds {
                guard let entry = mappings[remoteId] else { continue }

                await deletionQueue.enqueue(
                    localId: remoteId,
                    host: entry.host,
                    sharePath: entry.sharePath,
                    remotePath: entry.remotePath
                )

                enqueued += 1
            }

            logger.info("Enqueued \(enqueued) deletions.")
            return MirrorSyncResult(enqueuedDeletions: enqueued)
        }
    }
}
