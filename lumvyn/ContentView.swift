import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var queueManager: UploadQueueManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var inAppNotifications: InAppNotificationCenter

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showEntry = false
    @State private var selectedTab: AppTab = .mediathek

    var body: some View {
        ZStack {
            DSMeshBackdrop(palette: .aurora)
                .ignoresSafeArea()

            mainTabView

            if showEntry {
                EntryView {
                    withAnimation(DSMotion.hero) {
                        showEntry = false
                        hasCompletedOnboarding = true
                    }
                }
                .zIndex(1)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.02)),
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
        TabView(selection: $selectedTab) {
            MediathekView()
                .tag(AppTab.mediathek)
                .tabItem {
                    Label(LocalizedStringKey("tab.mediathek"), systemImage: "photo.stack.fill")
                }

            SammlungenView()
                .tag(AppTab.sammlungen)
                .tabItem {
                    Label(LocalizedStringKey("tab.sammlungen"), systemImage: "rectangle.stack.fill")
                }

            NavigationStack {
                OverviewView()
            }
            .tag(AppTab.overview)
            .tabItem {
                Label(LocalizedStringKey("Übersicht"), systemImage: "waveform.path.ecg.rectangle.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.settings)
            .tabItem {
                Label(LocalizedStringKey("tab.einstellungen"), systemImage: "slider.horizontal.3")
            }
        }
        .tint(DS.Palette.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

enum AppTab: Hashable {
    case mediathek
    case sammlungen
    case overview
    case settings
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
