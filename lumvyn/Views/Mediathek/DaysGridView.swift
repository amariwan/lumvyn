import SwiftUI

enum DaysScope: Hashable {
    case all
    case month(MonthGroup)
}

struct DaysGridView: View {
    let scope: DaysScope
    @EnvironmentObject private var galleryStore: GalleryStore

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    private var assets: [RemoteAsset] {
        switch scope {
        case .all: return galleryStore.allAssets
        case .month(let m): return m.assets
        }
    }

    private var days: [DayGroup] {
        PhotoGrouper.groupByDay(assets)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                if days.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("gallery.empty.title"),
                        systemImage: "calendar"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(days) { day in
                        Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 4)

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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(scopeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scopeTitle: String {
        switch scope {
        case .all: return ""
        case .month(let m):
            let f = DateFormatter()
            f.dateFormat = "LLLL yyyy"
            return f.string(from: m.monthStart).capitalized
        }
    }
}
