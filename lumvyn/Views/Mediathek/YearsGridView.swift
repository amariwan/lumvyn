import SwiftUI

struct YearsGridView: View {
    @EnvironmentObject private var galleryStore: GalleryStore

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    private var years: [YearGroup] {
        PhotoGrouper.groupByYear(galleryStore.allAssets)
    }

    var body: some View {
        ScrollView {
            if galleryStore.isLoadingAllAssets && years.isEmpty {
                ProgressView().padding(.top, 60)
            } else if years.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("gallery.empty.title"),
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(LocalizedStringKey("gallery.empty.subtitle"))
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(years) { year in
                        NavigationLink(value: year) {
                            YearCell(year: year)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
        }
    }
}

struct YearCell: View {
    let year: YearGroup
    @EnvironmentObject private var galleryStore: GalleryStore
    @State private var thumbnail: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color(.secondarySystemBackground)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(year.year))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    Text(String(format: NSLocalizedString("photos.count", comment: ""), year.count))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task {
            if let cover = year.cover,
               let data = await galleryStore.thumbnail(for: cover),
               let img = UIImage(data: data) {
                thumbnail = img
            }
        }
    }
}
