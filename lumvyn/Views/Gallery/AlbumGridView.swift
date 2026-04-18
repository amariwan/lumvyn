import SwiftUI

struct AlbumGridView: View {
    @EnvironmentObject private var galleryStore: GalleryStore

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    var body: some View {
        ScrollView {
            if galleryStore.isLoadingAlbums && galleryStore.albums.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if galleryStore.albums.isEmpty {
                GalleryEmptyView()
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(galleryStore.albums) { album in
                        NavigationLink(value: album) {
                            AlbumCardView(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .refreshable {
            await galleryStore.loadAlbums()
        }
    }
}

struct AlbumCardView: View {
    let album: RemoteAlbum
    @EnvironmentObject private var galleryStore: GalleryStore
    @State private var thumbnail: PlatformImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack {
                    Color.platformSecondaryBackground
                    if let thumbnail {
                        Image(platformImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.platformTertiaryLabel)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(album.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(album.assetCount > 0
                     ? album.assetCount.formatted()
                     : NSLocalizedString("gallery.album.empty", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .task {
            if let data = await galleryStore.coverThumbnail(for: album),
               let img = platformImage(from: data) {
                thumbnail = img
            }
        }
    }
}
