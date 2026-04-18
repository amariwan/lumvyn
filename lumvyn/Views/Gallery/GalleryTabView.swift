import SwiftUI

struct GalleryTabView: View {
    @EnvironmentObject private var galleryStore: GalleryStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var showSearch: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if !settingsStore.isConfigured {
                    GalleryUnconfiguredView()
                } else if let error = galleryStore.error, galleryStore.albums.isEmpty {
                    GalleryErrorView(error: error) {
                        Task { await galleryStore.loadAlbums() }
                    }
                } else {
                    AlbumGridView()
                }
            }
            .navigationTitle(LocalizedStringKey("gallery.tab.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(!settingsStore.isConfigured)
                }
            }
            .sheet(isPresented: $showSearch, onDismiss: {
                galleryStore.resetSearchAndFilters()
            }) {
                GallerySearchView()
                    .environmentObject(galleryStore)
            }
        }
        .task {
            if settingsStore.isConfigured && galleryStore.albums.isEmpty {
                await galleryStore.loadAlbums()
            }
        }
    }
}

struct GalleryUnconfiguredView: View {
    var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("gallery.unconfigured.title"), systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(LocalizedStringKey("gallery.error.noSMB"))
        }
    }
}

struct GalleryErrorView: View {
    let error: GalleryError
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("gallery.error.connectionFailed"), systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.errorDescription ?? "")
        } actions: {
            Button(LocalizedStringKey("Erneut versuchen"), action: onRetry)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct GalleryEmptyView: View {
    var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("gallery.empty.title"), systemImage: "photo.on.rectangle.angled")
        } description: {
            Text(LocalizedStringKey("gallery.empty.subtitle"))
        }
    }
}
