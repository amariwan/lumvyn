import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var queueManager: UploadQueueManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var inAppNotifications: InAppNotificationCenter

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showEntry = false

    var body: some View {
        ZStack {
            AppBackdropView()
                .ignoresSafeArea()

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
                    Label(LocalizedStringKey("tab.mediathek"), systemImage: "photo.stack.fill")
                }

            SammlungenView()
                .tabItem {
                    Label(LocalizedStringKey("tab.sammlungen"), systemImage: "rectangle.stack.fill")
                }

            NavigationStack {
                OverviewView()
            }
            .tabItem {
                Label(LocalizedStringKey("Übersicht"), systemImage: "waveform.path.ecg.rectangle.fill")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(LocalizedStringKey("tab.einstellungen"), systemImage: "slider.horizontal.3")
            }
        }
        .tint(Color(red: 0.10, green: 0.56, blue: 0.96))
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct AppBackdropView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            let gradientColors: [Color] = colorScheme == .dark
                ? [Color(red: 0.03, green: 0.05, blue: 0.08), Color(red: 0.06, green: 0.08, blue: 0.12), Color(red: 0.05, green: 0.07, blue: 0.14)]
                : [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.90, green: 0.96, blue: 1.0), Color(red: 0.95, green: 1.0, blue: 0.98)]

            let blob1 = colorScheme == .dark ? Color(red: 0.10, green: 0.42, blue: 0.62).opacity(0.28) : Color(red: 0.20, green: 0.76, blue: 0.95).opacity(0.30)
            let blob2 = colorScheme == .dark ? Color(red: 0.06, green: 0.35, blue: 0.72).opacity(0.20) : Color(red: 0.09, green: 0.53, blue: 0.94).opacity(0.20)
            let blob3 = colorScheme == .dark ? Color(red: 0.16, green: 0.50, blue: 0.34).opacity(0.16) : Color(red: 0.29, green: 0.86, blue: 0.64).opacity(0.18)

            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                GlowBlob(
                    color: blob1,
                    diameter: 320,
                    x: 90 + (sin(t * 0.45) * 52),
                    y: 150 + (cos(t * 0.36) * 34)
                )

                GlowBlob(
                    color: blob2,
                    diameter: 270,
                    x: 280 + (cos(t * 0.28) * 44),
                    y: 420 + (sin(t * 0.40) * 40)
                )

                GlowBlob(
                    color: blob3,
                    diameter: 210,
                    x: 190 + (sin(t * 0.33) * 26),
                    y: 690 + (cos(t * 0.27) * 28)
                )

                VStack {
                    LinearGradient(
                        colors: colorScheme == .dark ? [Color.black.opacity(0.18), .clear] : [Color.white.opacity(0.52), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 190)
                    Spacer()
                }
                .blendMode(.screen)
            }
        }
    }
}

private struct GlowBlob: View {
    let color: Color
    let diameter: CGFloat
    let x: CGFloat
    let y: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .blur(radius: 40)
            .position(x: x, y: y)
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
