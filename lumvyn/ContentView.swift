import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var queueManager: UploadQueueManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var inAppNotifications: InAppNotificationCenter

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showEntry = false

    var body: some View {
        ZStack {
            mainTabView

            if showEntry {
                EntryView {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        showEntry = false
                        hasCompletedOnboarding = true
                    }
                }
                .zIndex(1)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }

            InAppBannerView()
                .environmentObject(inAppNotifications)
                .allowsHitTesting(false)
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showEntry = true
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            MediathekView()
                .tabItem {
                    Label(LocalizedStringKey("tab.mediathek"), systemImage: "photo.stack")
                }

            SammlungenView()
                .tabItem {
                    Label(LocalizedStringKey("tab.sammlungen"), systemImage: "rectangle.stack")
                }

            NavigationStack {
                OverviewView()
            }
            .tabItem {
                Label(LocalizedStringKey("Übersicht"), systemImage: "arrow.up.circle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(LocalizedStringKey("tab.einstellungen"), systemImage: "gear")
            }
        }
        .tint(.blue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = SettingsStore()
        let smb = SMBClient()
        let remoteIndex = RemoteIndexStore()
        let galleryService = GalleryService(
            smbClient: smb,
            cache: GalleryThumbnailCache(),
            remoteIndex: remoteIndex
        )
        return ContentView()
            .environmentObject(UploadQueueManager(smbClient: smb, settingsStore: settings, remoteIndex: remoteIndex, remoteDeletionQueue: RemoteDeletionQueue(), inAppNotifications: InAppNotificationCenter.shared))
            .environmentObject(settings)
            .environmentObject(InAppNotificationCenter.shared)
            .environmentObject(GalleryStore(service: galleryService, settingsStore: settings))
    }
}
