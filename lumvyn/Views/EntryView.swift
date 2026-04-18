import SwiftUI

struct EntryView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    var onFinished: () -> Void

    @State private var currentPage = 0

    private var canProceed: Bool {
        let page = onboardingPages[currentPage]
        switch page.kind {
        case .smbSetup:
            guard isValidHost(settingsStore.host) else { return false }
            let share = settingsStore.sharePath.trimmed
            let hasShare = !share.isEmpty || (parseUNC(settingsStore.host)?.share?.trimmed.isEmpty == false)
            return hasShare && (
                settingsStore.lastConnectionSucceeded
                || settingsStore.connectionStatus == .ready
                || settingsStore.connectionStatus == .authenticated
            )
        case .info, .checklist:
            return true
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AnimatedBackground(page: onboardingPages[currentPage])
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.55), value: currentPage)

            TabView(selection: $currentPage) {
                ForEach(onboardingPages) { page in
                    Group {
                        switch page.kind {
                        case .info:
                            OnboardingPageView(page: page)
                        case .smbSetup:
                            SMBSetupPageView(page: page, settingsStore: settingsStore)
                        case .checklist:
                            ReadinessChecklistView(page: page, settingsStore: settingsStore)
                        }
                    }
                    .tag(page.id)
                }
            }
            #if os(iOS) || os(tvOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.82), value: currentPage)

            VStack(spacing: 20) {
                PageDotsView(total: onboardingPages.count, current: currentPage)

                BottomControlsView(
                    currentPage: currentPage,
                    totalPages: onboardingPages.count,
                    accentColor: onboardingPages[currentPage].accentColor,
                    pageKind: onboardingPages[currentPage].kind,
                    canProceed: canProceed,
                    onNext: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            currentPage = min(currentPage + 1, onboardingPages.count - 1)
                        }
                    },
                    onSkip: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            currentPage = onboardingPages.count - 1
                        }
                    },
                    onFinish: { onFinished() }
                )
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
        .ignoresSafeArea()
    }
}
