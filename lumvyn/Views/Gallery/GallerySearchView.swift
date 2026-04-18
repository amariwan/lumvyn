import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GallerySearchView: View {
    @EnvironmentObject private var galleryStore: GalleryStore
    @Environment(\.dismiss) private var dismiss

    @State private var aggregatedAssets: [RemoteAsset] = []
    @State private var isLoading = false

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 3),
        count: 3
    )

    private var results: [RemoteAsset] {
        galleryStore.filteredAssets(aggregatedAssets)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: NSLocalizedString("gallery.filter.photos", comment: ""),
                            isOn: galleryStore.activeFilters.mediaType == .photos
                        ) { toggleMediaType(.photos) }

                        FilterChip(
                            label: NSLocalizedString("gallery.filter.videos", comment: ""),
                            isOn: galleryStore.activeFilters.mediaType == .videos
                        ) { toggleMediaType(.videos) }

                        FilterChip(
                            label: NSLocalizedString("gallery.filter.backedUp", comment: ""),
                            isOn: galleryStore.activeFilters.backup == .backedUp
                        ) { toggleBackup(.backedUp) }

                        FilterChip(
                            label: NSLocalizedString("gallery.filter.notBackedUp", comment: ""),
                            isOn: galleryStore.activeFilters.backup == .notBackedUp
                        ) { toggleBackup(.notBackedUp) }

                        FilterChip(
                            label: NSLocalizedString("Letzte 7 Tage", comment: ""),
                            isOn: galleryStore.activeFilters.dateRange == .last7Days
                        ) { toggleDate(.last7Days) }

                        FilterChip(
                            label: NSLocalizedString("Letzte 30 Tage", comment: ""),
                            isOn: galleryStore.activeFilters.dateRange == .last30Days
                        ) { toggleDate(.last30Days) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }

                if results.isEmpty && !isLoading {
                    ContentUnavailableView.search(text: galleryStore.searchQuery)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(results) { asset in
                                AssetCellView(asset: asset)
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("gallery.search.placeholder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Fertig")) { dismiss() }
                }
            }
            .task {
                await indexAllAssets()
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                NSLocalizedString("gallery.search.placeholder", comment: ""),
                text: $galleryStore.searchQuery
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            if !galleryStore.searchQuery.isEmpty {
                Button {
                    galleryStore.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func toggleMediaType(_ value: GalleryMediaTypeFilter) {
        galleryStore.activeFilters.mediaType = galleryStore.activeFilters.mediaType == value ? .all : value
    }

    private func toggleBackup(_ value: GalleryBackupFilter) {
        galleryStore.activeFilters.backup = galleryStore.activeFilters.backup == value ? .all : value
    }

    private func toggleDate(_ value: GalleryDateRange) {
        galleryStore.activeFilters.dateRange = galleryStore.activeFilters.dateRange == value ? .all : value
    }

    private func indexAllAssets() async {
        isLoading = true
        defer { isLoading = false }
        var collected: [RemoteAsset] = []
        for album in galleryStore.albums {
            if let listing = await galleryStore.loadFolder(at: album.path) {
                collected.append(contentsOf: listing.assets)
            }
        }
        collected.sort { $0.modifiedAt > $1.modifiedAt }
        aggregatedAssets = collected
    }
}

private struct FilterChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isOn ? Color.accentColor : Color.secondarySystemBackground)
                )
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private extension Color {
    static var secondarySystemBackground: Color {
        #if canImport(UIKit)
        return Color(.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #else
        return Color.secondary.opacity(0.08)
        #endif
    }
}
