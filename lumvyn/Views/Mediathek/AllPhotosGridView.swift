import SwiftUI

struct AllPhotosGridView: View {
    @EnvironmentObject private var galleryStore: GalleryStore

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    private var assets: [RemoteAsset] {
        galleryStore.filteredAssets(galleryStore.allAssets)
    }

    var body: some View {
        ScrollView {
            if galleryStore.isLoadingAllAssets && assets.isEmpty {
                ProgressView().padding(.top, 60)
            } else if assets.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("gallery.empty.title"),
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(LocalizedStringKey("gallery.empty.subtitle"))
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(assets) { asset in
                        NavigationLink(value: AssetNavigation(asset: asset, siblings: assets)) {
                            AssetCellView(asset: asset)
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
