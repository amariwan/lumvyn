import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AssetGridView: View {
    let album: RemoteAlbum
    @EnvironmentObject private var galleryStore: GalleryStore

    @State private var subfolders: [RemoteAlbum] = []
    @State private var assets: [RemoteAsset] = []
    @State private var isLoading = false
    @State private var pendingDelete: RemoteAsset? = nil
    @State private var sharedItem: ShareItem? = nil

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    private var filteredAssets: [RemoteAsset] {
        galleryStore.filteredAssets(assets)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                if !subfolders.isEmpty {
                    SubfolderStrip(subfolders: subfolders)
                }

                if isLoading && assets.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if filteredAssets.isEmpty && subfolders.isEmpty {
                    ContentUnavailableView {
                        Label(LocalizedStringKey("gallery.empty.title"),
                              systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text(LocalizedStringKey("gallery.empty.subtitle"))
                    }
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(filteredAssets) { asset in
                            NavigationLink(value: AssetNavigation(asset: asset, siblings: filteredAssets)) {
                                AssetCellView(asset: asset)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await share(asset) }
                                } label: {
                                    Label(LocalizedStringKey("Teilen"), systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    pendingDelete = asset
                                } label: {
                                    Label(LocalizedStringKey("Löschen"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AssetNavigation.self) { nav in
            AssetDetailView(asset: nav.asset, siblings: nav.siblings)
        }
        .navigationDestination(for: RemoteAlbum.self) { album in
            AssetGridView(album: album)
        }
        .task(id: album.path) {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .alert(
            LocalizedStringKey("gallery.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { asset in
            Button(LocalizedStringKey("Abbrechen"), role: .cancel) { pendingDelete = nil }
            Button(LocalizedStringKey("Löschen"), role: .destructive) {
                Task { await delete(asset) }
            }
        } message: { _ in
            Text(LocalizedStringKey("gallery.delete.confirm.message"))
        }
        .sheet(item: $sharedItem) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        if let listing = await galleryStore.loadFolder(at: album.path) {
            subfolders = listing.subfolders
            assets = listing.assets
        }
    }

    private func delete(_ asset: RemoteAsset) async {
        do {
            try await galleryStore.delete(asset)
            assets.removeAll { $0.remotePath == asset.remotePath }
        } catch {
            galleryStore.error = (error as? GalleryError) ?? .deleteFailed(error.localizedDescription)
        }
        pendingDelete = nil
    }

    private func share(_ asset: RemoteAsset) async {
        do {
            let url = try await galleryStore.downloadFullResolution(asset)
            sharedItem = ShareItem(url: url)
        } catch {
            galleryStore.error = (error as? GalleryError) ?? .loadFailed(error.localizedDescription)
        }
    }
}

struct AssetNavigation: Hashable {
    let asset: RemoteAsset
    let siblings: [RemoteAsset]
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SubfolderStrip: View {
    let subfolders: [RemoteAlbum]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(subfolders) { folder in
                    NavigationLink(value: folder) {
                        SubfolderCell(folder: folder)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

struct SubfolderCell: View {
    let folder: RemoteAlbum
    @EnvironmentObject private var galleryStore: GalleryStore
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Color(.secondarySystemBackground)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(folder.name)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .task {
            if let data = await galleryStore.coverThumbnail(for: folder),
               let img = UIImage(data: data) {
                thumbnail = img
            }
        }
    }
}

struct AssetCellView: View {
    let asset: RemoteAsset
    @EnvironmentObject private var galleryStore: GalleryStore
    @State private var thumbnail: UIImage? = nil
    @State private var loadFailed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.secondarySystemBackground)

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else if loadFailed {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }

                if asset.mediaType == .video {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, y: 0.5)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 5)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topTrailing) {
                if asset.isBackedUp {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.45))
                        .padding(5)
                }
            }
        }
        .contentShape(Rectangle())
        .task(id: asset.remotePath) {
            let result = await galleryStore.thumbnail(for: asset)
            if Task.isCancelled { return }
            if let result, let img = UIImage(data: result) {
                thumbnail = img
            } else {
                loadFailed = true
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
