//
//  lumvynApp.swift
//  lumvyn
//
//  Created by Aland Baban on 11.04.26.
//

import SwiftUI

#if os(iOS)
    import BackgroundTasks
#endif

@main
struct lumvynApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var settingsStore: SettingsStore
    @StateObject private var queueManager: UploadQueueManager
    @StateObject private var photoWatcher: PhotoLibraryWatcher
    @StateObject private var inAppNotifications: InAppNotificationCenter
    @StateObject private var galleryStore: GalleryStore

    @MainActor
    init() {
        // shared infrastructure / dependency injection
        let smbClient = SMBClient()
        let settingsRepo = UserDefaultsSettingsRepository()
        let connectionService = ConnectionService(smbClient: smbClient)

        let settings = SettingsStore(smbClient: smbClient, repository: settingsRepo, connectionService: connectionService)
        // Apply persisted app language (nil means system default)
        Bundle.setLanguage(settings.selectedLanguage)

        let watcher = PhotoLibraryWatcher()
        let dedup = DeduplicationService()
        let remoteIndex = RemoteIndexStore()
        let remoteDeletionQueue = RemoteDeletionQueue()
        let inApp = InAppNotificationCenter.shared

        let queue = UploadQueueManager(
            smbClient: smbClient, settingsStore: settings, watcher: watcher,
            deduplicationService: dedup, remoteIndex: remoteIndex,
            remoteDeletionQueue: remoteDeletionQueue, inAppNotifications: inApp)
        watcher.delegate = queue

        let galleryService = GalleryService(
            smbClient: smbClient,
            cache: GalleryThumbnailCache(),
            remoteIndex: remoteIndex
        )
        let gallery = GalleryStore(service: galleryService, settingsStore: settings)

        self._settingsStore = StateObject(wrappedValue: settings)
        self._queueManager = StateObject(wrappedValue: queue)
        self._photoWatcher = StateObject(wrappedValue: watcher)
        self._inAppNotifications = StateObject(wrappedValue: InAppNotificationCenter.shared)
        self._galleryStore = StateObject(wrappedValue: gallery)

        #if os(iOS)
            BackgroundTaskManager.register(queueManager: queue, watcher: watcher)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(queueManager)
                .environmentObject(settingsStore)
                .environmentObject(inAppNotifications)
                .environmentObject(galleryStore)
                .task {
                    await queueManager.loadPendingQueue()
                    photoWatcher.start()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        settingsStore.reconnectOnForeground()
                        Task { await queueManager.startIfNeeded() }
                    } else if phase == .background {
                        #if os(iOS)
                        BackgroundTaskManager.scheduleBackgroundProcessing()
                        #endif
                    }
                }
        }
    }
}
