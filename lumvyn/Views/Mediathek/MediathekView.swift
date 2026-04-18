import SwiftUI

enum MediathekMode: String, CaseIterable, Identifiable {
    case years, months, days, all
    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .years: return "mediathek.jahre"
        case .months: return "mediathek.monate"
        case .days: return "mediathek.tage"
        case .all: return "mediathek.alle"
        }
    }
}

struct MediathekView: View {
    @EnvironmentObject private var galleryStore: GalleryStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var mode: MediathekMode = .all

    var body: some View {
        NavigationStack {
            Group {
                if !settingsStore.isConfigured {
                    GalleryUnconfiguredView()
                } else if let error = galleryStore.error, galleryStore.allAssets.isEmpty {
                    GalleryErrorView(error: error) {
                        Task { await galleryStore.loadAllAssets() }
                    }
                } else {
                    content
                }
            }
            .navigationTitle(LocalizedStringKey("tab.mediathek"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AssetNavigation.self) { nav in
                AssetDetailView(asset: nav.asset, siblings: nav.siblings)
            }
            .navigationDestination(for: MonthGroup.self) { month in
                DaysGridView(scope: .month(month))
            }
            .navigationDestination(for: YearGroup.self) { year in
                MonthsGridView(scope: .year(year))
            }
        }
        .task {
            if settingsStore.isConfigured && galleryStore.allAssets.isEmpty {
                await galleryStore.loadAllAssets()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(MediathekMode.allCases) { mode in
                    Text(mode.titleKey).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)

            switch mode {
            case .years:
                YearsGridView()
            case .months:
                MonthsGridView(scope: .all)
            case .days:
                DaysGridView(scope: .all)
            case .all:
                AllPhotosGridView()
            }
        }
        .refreshable {
            await galleryStore.loadAllAssets()
        }
    }
}
