import SwiftUI

enum MonthsScope: Hashable {
    case all
    case year(YearGroup)
}

struct MonthsGridView: View {
    let scope: MonthsScope
    @EnvironmentObject private var galleryStore: GalleryStore

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    private var assets: [RemoteAsset] {
        switch scope {
        case .all: return galleryStore.allAssets
        case .year(let y): return y.assets
        }
    }

    private var months: [MonthGroup] {
        PhotoGrouper.groupByMonth(assets)
    }

    var body: some View {
        ScrollView {
            if months.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("gallery.empty.title"),
                    systemImage: "calendar"
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(months) { month in
                        NavigationLink(value: month) {
                            MonthCell(month: month)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
        }
        .navigationTitle(scopeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scopeTitle: String {
        switch scope {
        case .all: return ""
        case .year(let y): return String(y.year)
        }
    }
}

struct MonthCell: View {
    let month: MonthGroup
    @EnvironmentObject private var galleryStore: GalleryStore
    @State private var thumbnail: PlatformImage? = nil

    private var label: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month.monthStart).capitalized
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color.platformSecondaryBackground
                if let thumbnail {
                    Image(platformImage: thumbnail)
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
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    Text(String(format: NSLocalizedString("photos.count", comment: ""), month.count))
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
            if let cover = month.cover,
               let data = await galleryStore.thumbnail(for: cover),
               let img = platformImage(from: data) {
                thumbnail = img
            }
        }
    }
}
