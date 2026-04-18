import SwiftUI

struct SammlungenView: View {
    @EnvironmentObject private var galleryStore: GalleryStore
    @EnvironmentObject private var settingsStore: SettingsStore

    private let albumColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var recentDays: [DayGroup] {
        PhotoGrouper.recentDays(galleryStore.allAssets, limit: 7)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !settingsStore.isConfigured {
                    GalleryUnconfiguredView()
                } else {
                    content
                }
            }
            .navigationTitle(LocalizedStringKey("tab.sammlungen"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: RemoteAlbum.self) { album in
                AssetGridView(album: album)
            }
            .navigationDestination(for: DayGroup.self) { day in
                DayDetailView(day: day)
            }
            .navigationDestination(for: AssetNavigation.self) { nav in
                AssetDetailView(asset: nav.asset, siblings: nav.siblings)
            }
        }
        .task {
            if settingsStore.isConfigured {
                if galleryStore.albums.isEmpty {
                    await galleryStore.loadAlbums()
                }
                if galleryStore.allAssets.isEmpty {
                    await galleryStore.loadAllAssets()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !recentDays.isEmpty {
                    CollectionSectionHeader(title: LocalizedStringKey("sammlungen.letztetage"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentDays) { day in
                                NavigationLink(value: day) {
                                    RecentDayCard(day: day)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                CollectionSectionHeader(title: LocalizedStringKey("sammlungen.meinealben"))
                if galleryStore.albums.isEmpty {
                    if galleryStore.isLoadingAlbums {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        Text(LocalizedStringKey("gallery.empty.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                } else {
                    LazyVGrid(columns: albumColumns, spacing: 20) {
                        ForEach(galleryStore.albums) { album in
                            NavigationLink(value: album) {
                                AlbumCardView(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .refreshable {
            await galleryStore.loadAlbums()
            await galleryStore.loadAllAssets()
        }
    }
}

struct RecentDayCard: View {
    let day: DayGroup
    @EnvironmentObject private var galleryStore: GalleryStore
    @State private var thumbnail: PlatformImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.platformSecondaryBackground
                if let thumbnail {
                    Image(platformImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.platformTertiaryLabel)
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(day.date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(day.date.formatted(.dateTime.day().month()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: NSLocalizedString("photos.count", comment: ""), day.count))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 160, alignment: .leading)
        .task {
            if let cover = day.cover,
               let data = await galleryStore.thumbnail(for: cover),
               let img = platformImage(from: data) {
                thumbnail = img
            }
        }
    }
}

struct DayDetailView: View {
    let day: DayGroup

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(day.assets) { asset in
                    NavigationLink(value: AssetNavigation(asset: asset, siblings: day.assets)) {
                        AssetCellView(asset: asset)
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }
}
