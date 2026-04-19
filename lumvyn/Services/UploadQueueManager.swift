import Foundation
import os
import Combine
import Network
import Photos
import WidgetKit

@MainActor
final class UploadQueueManager: ObservableObject, PhotoLibraryWatcherDelegate {
    @Published private(set) var items: [UploadItem] = []
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var uploadRateBytesPerSecond: Double = 0
    @Published private(set) var cacheSizeBytes: Int64 = 0
    @Published private(set) var pendingDeletionCount: Int = 0
    @Published private(set) var isProcessingDeletions: Bool = false

    private let persistenceURL: URL
    private let cacheDirectory: URL
    private let smbClient: SMBClientProtocol
    private let settingsStore: SettingsStore
    private let deduplicationService: DeduplicationService?
    private let remoteIndex: RemoteIndexStore?
    private let remoteDeletionQueue: RemoteDeletionQueue?
    private let inAppNotifications: InAppNotificationCenter?
    private let mirrorSyncEngine = MirrorSyncEngine()
    private var cancellables = Set<AnyCancellable>()
    private var fingerprintVariantsMap: [UUID: [String]] = [:]
    private var processingTask: Task<Void, Never>?
    private let networkMonitor = NetworkMonitor.shared
    private weak var photoLibraryWatcher: PhotoLibraryWatcher?
    init(smbClient: SMBClientProtocol, settingsStore: SettingsStore, watcher: PhotoLibraryWatcher? = nil, deduplicationService: DeduplicationService? = nil, remoteIndex: RemoteIndexStore? = nil, remoteDeletionQueue: RemoteDeletionQueue? = nil, inAppNotifications: InAppNotificationCenter? = nil) {
        self.smbClient = smbClient
        self.settingsStore = settingsStore
        self.deduplicationService = deduplicationService
        self.remoteIndex = remoteIndex
        self.remoteDeletionQueue = remoteDeletionQueue
        self.inAppNotifications = inAppNotifications
        self.photoLibraryWatcher = watcher

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        persistenceURL = caches.appendingPathComponent("upload-queue.json")
        cacheDirectory = caches.appendingPathComponent("media-export", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        watcher?.delegate = self

        // Retry pending deletions when network becomes available
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                if connected {
                    Task { await self.autoResumeProcessingIfNeeded() }
                    Task { await self.runMirrorSyncIfNeeded() }
                }

                Task {
                    if let dq = self.remoteDeletionQueue {
                        let pending = await dq.pendingCount()
                        if pending > 0 {
                            await MainActor.run { self.isProcessingDeletions = true }
                            self.inAppNotifications?.show(title: NSLocalizedString("Löschungen werden erneut versucht", comment: "Retrying deletions"), message: String(format: NSLocalizedString("Versuche %d ausstehende Löschungen", comment: "Trying pending deletions"), pending), type: .info, duration: 0)
                            let result = await dq.processPending(smbClient: self.smbClient, credentials: self.settingsStore.credentials, remoteIndex: self.remoteIndex)
                            await self.refreshPendingDeletionCount()
                            await MainActor.run { self.isProcessingDeletions = false }
                            var msg: String? = nil
                            if result.deleted > 0 && result.failed == 0 {
                                msg = String(format: NSLocalizedString("%d Dateien erfolgreich gelöscht.", comment: "Deleted count"), result.deleted)
                                self.inAppNotifications?.show(title: NSLocalizedString("Löschungen abgeschlossen", comment: "Deletions complete"), message: msg, type: .success)
                            } else if result.deleted > 0 || result.failed > 0 {
                                msg = String(format: NSLocalizedString("Gelöscht: %d, Fehlgeschlagen: %d", comment: "Deleted/failed summary"), result.deleted, result.failed)
                                let t: InAppNotificationType = result.failed > 0 ? .warning : .success
                                self.inAppNotifications?.show(title: NSLocalizedString("Löschungs-Update", comment: "Deletion update"), message: msg, type: t)
                            } else {
                                self.inAppNotifications?.dismiss()
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)

        networkMonitor.$connectionType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.autoResumeProcessingIfNeeded() }
            }
            .store(in: &cancellables)

        settingsStore.$autoUploadEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.autoResumeProcessingIfNeeded() }
            }
            .store(in: &cancellables)

        settingsStore.$uploadSchedule
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.autoResumeProcessingIfNeeded() }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            $items.map { items -> Int in items.filter { $0.status == .pending || $0.status == .failed }.count },
            $isProcessing
        )
        .removeDuplicates { $0 == $1 }
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] pending, syncing in
            self?.writeWidgetState(pending: pending, isSyncing: syncing)
        }
        .store(in: &cancellables)
    }

    private func writeWidgetState(pending: Int, isSyncing: Bool) {
        if let ud = UserDefaults(suiteName: WidgetShared.appGroup) {
            ud.set(pending, forKey: WidgetShared.keyPending)
            ud.set(isSyncing, forKey: WidgetShared.keyIsSyncing)
        }
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.kind)
        }
    }

    private func recordSyncCompletion() {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        UserDefaults(suiteName: WidgetShared.appGroup)?.set(stamp, forKey: WidgetShared.keyLastSyncText)
    }

    private var hasRetryableItems: Bool {
        items.contains { $0.status == .pending || ($0.status == .failed && $0.retryCount < Constants.maxRetryCount) }
    }

    private func shouldAutoStartUploads() -> Bool {
        settingsStore.autoUploadEnabled &&
        settingsStore.config.uploadSchedule != .manual &&
        settingsStore.isConfigured &&
        hasRetryableItems
    }

    private func autoResumeProcessingIfNeeded() async {
        guard shouldAutoStartUploads() else { return }
        await startIfNeeded()
    }

    nonisolated func photoLibraryWatcher(_ watcher: PhotoLibraryWatcher, didDetect newAssets: [PHAsset]) {
        Task {
            await enqueueAssets(newAssets)
            await runMirrorSyncIfNeeded()
        }
    }

    func loadPendingQueue() async {
        await loadQueue()
        await recalcCacheSize()
        if settingsStore.autoUploadEnabled {
            await startIfNeeded()
        }
        if settingsStore.syncMode == .mirror {
            await runMirrorSyncIfNeeded()
        } else {
            if let dq = remoteDeletionQueue {
                _ = await dq.processPending(smbClient: smbClient, credentials: settingsStore.credentials, remoteIndex: remoteIndex)
                await refreshPendingDeletionCount()
            }
        }
    }

    private func syncDeletions() async {
        await runMirrorSyncIfNeeded()
    }

    func refreshPendingDeletionCount() async {
        pendingDeletionCount = await remoteDeletionQueue?.pendingCount() ?? 0
    }

    func runMirrorSyncIfNeeded() async {
        guard settingsStore.syncMode == .mirror else { return }
        guard let index = remoteIndex, let dq = remoteDeletionQueue else { return }
        guard settingsStore.config.isValid else { return }

        let wifiOnly = settingsStore.config.wifiOnlyUpload
        let result = await mirrorSyncEngine.runSync(
            remoteIndex: index,
            deletionQueue: dq,
            wifiOnly: wifiOnly,
            networkMonitor: networkMonitor
        )

        if result.safetyAborted {
            let reason = result.abortReason ?? NSLocalizedString("Unbekannter Grund", comment: "")
            inAppNotifications?.show(
                title: NSLocalizedString("Spiegel-Sync abgebrochen", comment: "Mirror sync aborted title"),
                message: reason,
                type: .warning
            )
            return
        }

        if result.skippedNetworkUnavailable {
            inAppNotifications?.show(
                title: NSLocalizedString("Spiegel-Sync übersprungen", comment: "Mirror sync skipped"),
                message: NSLocalizedString("WLAN erforderlich – derzeit nicht verbunden.", comment: "Wi-Fi required, not connected"),
                type: .info
            )
            return
        }

        if result.enqueuedDeletions > 0 {
            await refreshPendingDeletionCount()
            isProcessingDeletions = true
            let processResult = await dq.processPending(
                smbClient: smbClient,
                credentials: settingsStore.credentials,
                remoteIndex: index
            )
            isProcessingDeletions = false
            await refreshPendingDeletionCount()

            if processResult.deleted > 0 || processResult.failed > 0 {
                let msg = String(
                    format: NSLocalizedString("Gelöscht: %d, Fehlgeschlagen: %d", comment: ""),
                    processResult.deleted, processResult.failed
                )
                let type: InAppNotificationType = processResult.failed > 0 ? .warning : .success
                inAppNotifications?.show(
                    title: NSLocalizedString("Spiegel-Sync abgeschlossen", comment: "Mirror sync done"),
                    message: msg,
                    type: type
                )
            }
        }
    }

    func retryPendingDeletions() async {
        guard let dq = remoteDeletionQueue else { return }
        isProcessingDeletions = true
        inAppNotifications?.show(title: NSLocalizedString("Löschvorgang gestartet", comment: "Deletion retry started"), message: NSLocalizedString("Versuche ausstehende Löschungen...", comment: "Trying pending deletions"), type: .info, duration: 0)
        let result = await dq.processPending(smbClient: smbClient, credentials: settingsStore.credentials, remoteIndex: remoteIndex)
        isProcessingDeletions = false
        await refreshPendingDeletionCount()
        if result.deleted > 0 || result.failed > 0 {
            let msg = String(format: NSLocalizedString("Gelöscht: %d, Fehlgeschlagen: %d", comment: "Deleted/failed summary"), result.deleted, result.failed)
            let t: InAppNotificationType = result.failed > 0 ? .warning : .success
            inAppNotifications?.show(title: NSLocalizedString("Löschungs-Update", comment: "Deletion update"), message: msg, type: t)
        } else {
            inAppNotifications?.show(title: NSLocalizedString("Keine ausstehenden Löschungen", comment: "No pending deletions"), message: nil, type: .info)
        }
    }

    func clearPendingDeletionQueue() async {
        await remoteDeletionQueue?.clearAll()
        await refreshPendingDeletionCount()
    }

    func enqueueAssets(_ assets: [PHAsset]) async {
        let newAssets = assets.filter { asset in
            !items.contains { $0.assetLocalIdentifier == asset.localIdentifier }
        }

        guard !newAssets.isEmpty else { return }

        let filtered = await filterAssets(newAssets)
        var newItems: [UploadItem] = []

        for asset in filtered {
            let snapshot = await Task.detached(priority: .utility) { () async -> AssetSnapshot in
                return await extractAssetSnapshot(asset)
            }.value

            var fingerprint: String? = nil
            var fingerprintVariants: [String] = []
            if settingsStore.deduplicationEnabled, let dedup = deduplicationService {
                do {
                    fingerprintVariants = try await dedup.fingerprints(for: asset)
                    var skip = false
                    for fp in fingerprintVariants {
                        if await dedup.contains(fp) {
                            skip = true
                            break
                        }
                    }
                    if skip { continue }
                    // keep the file-bytes fingerprint as the canonical stored value (preserves prior behavior)
                    fingerprint = fingerprintVariants.first
                } catch {
                    fingerprint = nil
                }
            }

            let item = UploadItem(
                assetLocalIdentifier: snapshot.localIdentifier,
                fileName: snapshot.fileName,
                mediaType: snapshot.mediaType == .video ? .video : .photo,
                createdAt: snapshot.createdAt,
                albumName: snapshot.albumName,
                locationName: snapshot.locationName,
                isFavorite: snapshot.isFavorite,
                isHidden: snapshot.isHidden,
                pixelWidth: snapshot.pixelWidth,
                pixelHeight: snapshot.pixelHeight,
                sourceType: snapshot.sourceTypeName,
                subtypes: snapshot.subtypeNames,
                burstIdentifier: snapshot.burstIdentifier,
                fileSize: nil,
                fingerprint: fingerprint,
                priority: snapshot.mediaType == .video ? 20 : 10,
                assetDuration: snapshot.duration
            )

            newItems.append(item)
            if !fingerprintVariants.isEmpty {
                fingerprintVariantsMap[item.id] = fingerprintVariants
            }
        }

        items.append(contentsOf: newItems)
        saveQueue()

        if settingsStore.autoUploadEnabled {
            await startIfNeeded()
        }
    }

    func startIfNeeded(force: Bool = false) async {
        guard processingTask == nil else {
            return
        }

        if !force {
            guard canUploadNow() else { return }
            if settingsStore.config.uploadSchedule == .manual {
                return
            }
        }


        processingTask = Task {
            await runUploadLoop()
            processingTask = nil
        }
    }

    func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
    }

    func scanLibraryAndImport() async {
        await photoLibraryWatcher?.scanLibrary()
        await startIfNeeded(force: true)
    }

    func retry(item: UploadItem) async {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].status = .pending
            items[index].retryCount = 0
            items[index].lastError = nil
            items[index].progress = 0.0
            saveQueue()
            await startIfNeeded(force: true)
        }
    }

    func retryAll() async {
        var updated = false

        for index in items.indices {
            if items[index].status == .failed {
                items[index].status = .pending
                items[index].retryCount = 0
                items[index].lastError = nil
                items[index].progress = 0.0
                updated = true
            }
        }

        guard updated else { return }

        saveQueue()
        await startIfNeeded(force: true)
    }

    func remove(item: UploadItem) {
        guard item.status != .uploading else { return }
        items.removeAll { $0.id == item.id }
        saveQueue()
    }

    func remove(atOffsets offsets: IndexSet) {
        let toRemove = offsets.compactMap { idx -> UploadItem? in
            guard items.indices.contains(idx) else { return nil }
            return items[idx]
        }
        for item in toRemove {
            remove(item: item)
        }
    }

    private enum Constants {
        static let maxRetryCount = 3
    }

    func clearCompleted() {
        items.removeAll { $0.status == .done }
        saveQueue()
    }

    func clearCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        Task.detached { await self.recalcCacheSize() }
    }

    private func runUploadLoop() async {
        isProcessing = true
        defer {
            isProcessing = false
            recordSyncCompletion()
        }

        var successCount = 0
        var failureCount = 0
        let concurrency = max(1, settingsStore.config.maxConcurrentUploads)

        while !Task.isCancelled {
            let batch = items
                .filter { $0.status == .pending || ($0.status == .failed && $0.retryCount < Constants.maxRetryCount) }
                .prefix(concurrency)

            guard !batch.isEmpty else { break }

            await withTaskGroup(of: Bool.self) { group in
                for item in batch {
                    let itemCopy = item
                    // capture fingerprint variants for this item so background tasks can mark all of them
                    let variantsForItem = fingerprintVariantsMap[itemCopy.id]
                    // Snapshot settings needed for background work
                    let host = settingsStore.host
                    let sharePath = settingsStore.sharePath
                    let conflictResolution = settingsStore.config.conflictResolution
                    let encryptionEnabled = settingsStore.config.encryptionEnabled
                    let encryptionKey = settingsStore.encryptionKey
                    // Ensure credentials exist for background upload; if not, mark failed later
                    let credentials = settingsStore.credentials
                    let remoteDir = remoteDirectory(for: itemCopy)
                    let remotePath = buildRemotePath(for: itemCopy)
                    let configValid = settingsStore.config.isValid
                    let deduplicationEnabled = settingsStore.deduplicationEnabled

                    group.addTask { [weak self] in
                        guard let self else { return false }

                        // Quick pre-checks on captured settings
                        guard let creds = credentials, configValid else {
                            await MainActor.run { self.markFailed(itemCopy.id, message: NSLocalizedString("SMB-Konfiguration oder Credentials fehlen.", comment: "SMB configuration missing")) }
                            return false
                        }

                        let context = UploadContext(
                            host: host,
                            sharePath: sharePath,
                            credentials: creds,
                            encryptionEnabled: encryptionEnabled,
                            encryptionKey: encryptionKey,
                            conflictResolution: conflictResolution,
                            cacheDirectory: self.cacheDirectory
                        )

                        do {
                            if !remoteDir.isEmpty {
                                try await self.smbClient.ensureDirectory(
                                    host: host,
                                    sharePath: sharePath,
                                    remoteDirectory: remoteDir,
                                    credentials: creds
                                )
                            }
                            let (finalRemotePath, _) = try await performBackgroundUpload(item: itemCopy, remotePath: remotePath, context: context, smbClient: self.smbClient) { progress in
                                Task { await MainActor.run { self.updateProgress(itemCopy.id, progress: progress) } }
                            }

                            // Update UI state on main actor
                            await MainActor.run {
                                self.updateItem(id: itemCopy.id) { var i = $0; i.status = .done; i.progress = 1.0; i.lastError = nil; i.retryCount = 0; return i }
                            }

                            // Persist mapping and mark deduplication on background
                            if let index = self.remoteIndex {
                                Task.detached(priority: .utility) {
                                    await index.saveMapping(localId: itemCopy.assetLocalIdentifier, host: host, sharePath: sharePath, remotePath: finalRemotePath, fingerprint: itemCopy.fingerprint)
                                }
                            }
                            if deduplicationEnabled, let dedup = self.deduplicationService {
                                let variants = variantsForItem ?? (itemCopy.fingerprint.map { [$0] } ?? [])
                                Task {
                                    for v in variants { await dedup.markUploaded(fingerprint: v) }
                                }
                                // clear stored variants for this item
                                self.fingerprintVariantsMap[itemCopy.id] = nil
                            }

                            return true
                        } catch {
                            await MainActor.run { self.markFailed(itemCopy.id, message: (error as NSError).localizedDescription) }
                            return false
                        }
                    }
                }

                for await success in group {
                    if success { successCount += 1 } else { failureCount += 1 }
                }
            }
        }

        NotificationService.shared.sendUploadCompleteNotification(successCount: successCount, failureCount: failureCount)
    }

    private func upload(_ item: UploadItem) async throws {
        updateItem(id: item.id) { item in
            var item = item
            item.status = .uploading
            item.progress = 0.0
            item.lastError = nil
            return item
        }

        guard settingsStore.config.isValid, let credentials = settingsStore.credentials else {
            let m = NSLocalizedString("SMB-Konfiguration oder Credentials fehlen.", comment: "SMB configuration missing")
            markFailed(item.id, message: m)
            throw SMBClientError.notConfigured
        }

        if settingsStore.config.wifiOnlyUpload && !networkMonitor.isWifiConnected {
            let m = NSLocalizedString("WLAN erforderlich für Upload.", comment: "Wi-Fi required for upload")
            markFailed(item.id, message: m)
            throw SMBClientError.uploadFailed(
                NSError(domain: "UploadQueueManager", code: -1, userInfo: [NSLocalizedDescriptionKey: m])
            )
        }

        do {
            let localURL = try await exportAsset(for: item)
            let uploadURL = try await prepareUploadFile(for: localURL)
            let remotePath = buildRemotePath(for: item)
            let fileSize = fileSizeBytes(at: uploadURL)
            let start = Date()

            let finalRemotePath = try await smbClient.upload(
                fileURL: uploadURL,
                to: remotePath,
                host: settingsStore.host,
                sharePath: settingsStore.sharePath,
                credentials: credentials,
                conflictResolution: settingsStore.config.conflictResolution
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.updateProgress(item.id, progress: progress)
                }
            }

            if uploadURL != localURL {
                try? FileManager.default.removeItem(at: uploadURL)
            }
            try? FileManager.default.removeItem(at: localURL)

            if let bytes = fileSize {
                let duration = Date().timeIntervalSince(start)
                if duration > 0 {
                    uploadRateBytesPerSecond = Double(bytes) / duration
                }
            }

            updateItem(id: item.id) { item in
                var item = item
                item.status = .done
                item.progress = 1.0
                item.lastError = nil
                item.retryCount = 0
                return item
            }
            if let index = remoteIndex {
                let host = settingsStore.host
                let sharePath = settingsStore.sharePath
                Task.detached(priority: .utility) {
                    await index.saveMapping(localId: item.assetLocalIdentifier, host: host, sharePath: sharePath, remotePath: finalRemotePath, fingerprint: item.fingerprint)
                }
            }
            if settingsStore.deduplicationEnabled, let dedup = deduplicationService {
                let variants = fingerprintVariantsMap[item.id] ?? (item.fingerprint.map { [$0] } ?? [])
                for v in variants { await dedup.markUploaded(fingerprint: v) }
                fingerprintVariantsMap[item.id] = nil
            }
        } catch {
            let nsError = error as NSError
            let code = nsError.code
            let desc = nsError.localizedDescription

            var logMessage = "\(desc) (\(nsError.domain) code: \(code))"
            if code == 1 {
                logMessage += " — " + NSLocalizedString("Mögliche Ursache: fehlende Berechtigungen oder ungültige Credentials. Prüfe Benutzer/Share-Rechte.", comment: "Upload error hint: permission denied")
            }

            NSLog("Upload fehlgeschlagen für %@: %@", item.fileName, logMessage)
            markFailed(item.id, message: desc)
            throw error
        }

        saveQueue()
    }

    private func prepareUploadFile(for url: URL) async throws -> URL {
        guard settingsStore.config.encryptionEnabled else {
            return url
        }

        guard let key = settingsStore.encryptionKey, !key.isEmpty else {
            throw SMBClientError.uploadFailed(
                NSError(domain: "UploadQueueManager", code: -2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Verschlüsselung aktiviert, aber Schlüssel fehlt.", comment: "Encryption enabled but key missing")])
            )
        }

        // Offload heavy file read + encryption to a background task to avoid blocking the actor
        let cacheDirCopy = cacheDirectory
        let keyCopy = key
        let filename = url.lastPathComponent

        let encryptedURL = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [cacheDirCopy, keyCopy, filename, url] in
                do {
                    let service = EncryptionService(password: keyCopy)
                    let data = try Data(contentsOf: url)
                    let encrypted = try service.encrypt(data)
                    let outURL = cacheDirCopy.appendingPathComponent("encrypted_\(filename)")
                    try encrypted.write(to: outURL, options: [.atomic])
                    continuation.resume(returning: outURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return encryptedURL
    }

    private func canUploadNow() -> Bool {
        if !networkMonitor.isConnected { return false }
        if settingsStore.config.wifiOnlyUpload && !networkMonitor.isWifiConnected {
            return false
        }
        if !settingsStore.config.allowCellularUpload && networkMonitor.connectionType == .cellular {
            return false
        }
        return true
    }

    private func filterAssets(_ assets: [PHAsset]) async -> [PHAsset] {
        assets.filter { asset in
            settingsStore.config.mediaTypeFilter.matches(asset: asset) &&
            settingsStore.config.dateRangeOption.matches(asset.creationDate ?? Date()) &&
            assetMatchesAlbumFilter(asset)
        }
    }

    private func assetMatchesAlbumFilter(_ asset: PHAsset) -> Bool {
        guard settingsStore.config.albumFilterEnabled,
              !settingsStore.config.selectedAlbums.isEmpty else {
            return true
        }

        let collections = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
        var matches = false
        collections.enumerateObjects { collection, _, stop in
            if let title = collection.localizedTitle,
               self.settingsStore.config.selectedAlbums.contains(title) {
                matches = true
                stop.pointee = true
            }
        }
        return matches
    }

    private func remoteDirectory(for item: UploadItem) -> String {
        let normalized = settingsStore.sharePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseSubPath: String
        if let slashIdx = normalized.firstIndex(of: "/") {
            baseSubPath = String(normalized[normalized.index(after: slashIdx)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            baseSubPath = ""
        }

        let template = settingsStore.folderTemplate
        let resolved = FolderTemplateResolver.resolve(
            template: template,
            input: FolderTemplateResolver.Input(
                createdAt: item.createdAt,
                albumName: item.albumName,
                isVideo: item.mediaType.isVideo
            )
        )

        switch (baseSubPath.isEmpty, resolved.isEmpty) {
        case (true, true):   return ""
        case (false, true):  return baseSubPath
        case (true, false):  return resolved
        case (false, false): return baseSubPath + "/" + resolved
        }
    }

    private func buildRemotePath(for item: UploadItem) -> String {
        let dir = remoteDirectory(for: item)
        return dir.isEmpty ? item.fileName : dir + "/" + item.fileName
    }

    private func exportAsset(for item: UploadItem) async throws -> URL {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [item.assetLocalIdentifier], options: nil)
        guard let asset = fetch.firstObject else {
            throw SMBClientError.uploadFailed(
                NSError(domain: "UploadQueueManager", code: -3, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Asset nicht gefunden", comment: "Asset not found")])
            )
        }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            throw SMBClientError.uploadFailed(
                NSError(domain: "UploadQueueManager", code: -4, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Keine Asset-Ressource verfügbar", comment: "No asset resource available")])
            )
        }

        let exportURL = cacheDirectory.appendingPathComponent(resource.originalFilename)
        try FileManager.default.removeItemIfExists(at: exportURL)

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().writeData(for: resource, toFile: exportURL, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: exportURL)
                }
            }
        }
    }

    private func fileSizeBytes(at url: URL) -> Int64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize else {
            return nil
        }
        return Int64(size)
    }

    private func markFailed(_ id: UUID, message: String) {
        updateItem(id: id) { item in
            var item = item
            item.status = .failed
            item.retryCount += 1
            item.lastError = message
            return item
        }

        lastErrorMessage = items.first(where: { $0.id == id })?.lastError
    }

    private func updateProgress(_ id: UUID, progress: Double) {
        updateItem(id: id) { item in
            var item = item
            item.progress = progress
            return item
        }
    }

    private func updateItem(id: UUID, update: (UploadItem) -> UploadItem) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index] = update(items[index])
    }

    private func saveQueue() {
        let snapshot = items
        let url = persistenceURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: [.atomic])
            } catch {
                Task { @MainActor in
                    uploadLogger.error("Speicherfehler Upload-Queue: \(String(describing: error))")
                }
            }
        }
    }

    private func loadQueue() async {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
            await MainActor.run { self.items = [] }
            return
        }
        let url = persistenceURL
        do {
            let data = try await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
            let decoded = try JSONDecoder().decode([UploadItem].self, from: data)
            await MainActor.run { self.items = decoded }
        } catch {
            await MainActor.run { self.items = [] }
            uploadLogger.error("Ladefehler Upload-Queue: \(String(describing: error))")
        }
    }

    private func recalcCacheSize() async {
        let dir = cacheDirectory
        let size = await Task.detached(priority: .utility) { () -> Int64 in
            return (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [])
                .reduce(into: Int64(0)) { partialResult, fileURL in
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        partialResult += Int64(fileSize)
                    }
                }) ?? 0
        }.value
        await MainActor.run { self.cacheSizeBytes = size }
    }
}

fileprivate let uploadLogger = Logger(subsystem: "tasio.lumvyn", category: "UploadQueueManager")

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}

fileprivate struct AssetSnapshot {
    let localIdentifier: String
    let fileName: String
    let mediaType: PHAssetMediaType
    let createdAt: Date
    let albumName: String?
    let locationName: String?
    let isFavorite: Bool
    let isHidden: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let sourceTypeName: String
    let subtypeNames: [String]
    let burstIdentifier: String?
    let duration: TimeInterval
}

fileprivate func extractAssetSnapshot(_ asset: PHAsset) async -> AssetSnapshot {
    let localIdentifier = asset.localIdentifier

    let resource = PHAssetResource.assetResources(for: asset).first
    let fileName: String
    if let name = resource?.originalFilename, !name.isEmpty {
        fileName = name
    } else {
        let suffix = asset.mediaType == .video ? "mp4" : "jpg"
        fileName = "media_\(localIdentifier).\(suffix)"
    }

    let (createdAt, locationName, isFavorite) = await MainActor.run {
        (asset.creationDate ?? Date(), asset.locationDescription, asset.isFavorite)
    }
    let collections = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
    let albumName = collections.firstObject?.localizedTitle
    let isHidden = asset.isHidden
    let pixelWidth = asset.pixelWidth
    let pixelHeight = asset.pixelHeight
    let sourceTypeName = asset.sourceTypeName
    let subtypeNames = asset.subtypeNames
    let burstIdentifier = asset.burstIdentifier
    let duration = asset.duration
    return AssetSnapshot(
        localIdentifier: localIdentifier,
        fileName: fileName,
        mediaType: asset.mediaType,
        createdAt: createdAt,
        albumName: albumName,
        locationName: locationName,
        isFavorite: isFavorite,
        isHidden: isHidden,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
        sourceTypeName: sourceTypeName,
        subtypeNames: subtypeNames,
        burstIdentifier: burstIdentifier,
        duration: duration
    )
}

// Background upload helpers (non-actor work)
fileprivate struct UploadContext: Sendable {
    let host: String
    let sharePath: String
    let credentials: SMBCredentials
    let encryptionEnabled: Bool
    let encryptionKey: String?
    let conflictResolution: ConflictResolution
    let cacheDirectory: URL
}

fileprivate func performBackgroundUpload(
    item: UploadItem,
    remotePath: String,
    context: UploadContext,
    smbClient: SMBClientProtocol,
    progressHandler: @escaping @Sendable (Double) -> Void
) async throws -> (String, Int64?) {
    // Export asset to a temporary file
    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [item.assetLocalIdentifier], options: nil)
    guard let asset = fetch.firstObject else {
        throw SMBClientError.uploadFailed(NSError(domain: "UploadQueueManager", code: -3, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Asset nicht gefunden", comment: "Asset not found")]))
    }

    guard let resource = PHAssetResource.assetResources(for: asset).first else {
        throw SMBClientError.uploadFailed(NSError(domain: "UploadQueueManager", code: -4, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Keine Asset-Ressource verfügbar", comment: "No asset resource available")]))
    }

    let exportURL = context.cacheDirectory.appendingPathComponent("\(UUID().uuidString)_\(resource.originalFilename)")
    try? FileManager.default.removeItem(at: exportURL)

    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        PHAssetResourceManager.default().writeData(for: resource, toFile: exportURL, options: options) { error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }

    var uploadURL = exportURL

    // Optional encryption (keeps memory approach for now)
    if context.encryptionEnabled {
        guard let key = context.encryptionKey, !key.isEmpty else {
            throw SMBClientError.uploadFailed(NSError(domain: "UploadQueueManager", code: -2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Verschlüsselung aktiviert, aber Schlüssel fehlt.", comment: "Encryption enabled but key missing")] ))
        }

        let service = EncryptionService(password: key)
        let data = try await Task.detached(priority: .utility) { try Data(contentsOf: exportURL) }.value
        let encrypted = try service.encrypt(data)
        let outURL = context.cacheDirectory.appendingPathComponent("encrypted_\(exportURL.lastPathComponent)")
        try encrypted.write(to: outURL, options: [.atomic])
        uploadURL = outURL
    }

    let fileSize = (try? uploadURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }

    let finalRemotePath = try await smbClient.upload(
        fileURL: uploadURL,
        to: remotePath,
        host: context.host,
        sharePath: context.sharePath,
        credentials: context.credentials,
        conflictResolution: context.conflictResolution
    ) { progress in
        progressHandler(progress)
    }

    // Cleanup temporary files
    if uploadURL != exportURL { try? FileManager.default.removeItem(at: uploadURL) }
    try? FileManager.default.removeItem(at: exportURL)

    return (finalRemotePath, fileSize)
}
