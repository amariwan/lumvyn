import Combine
import Foundation
import SwiftUI

@MainActor
final class GalleryStore: ObservableObject {
    @Published var albums: [RemoteAlbum] = []
    @Published var allAssets: [RemoteAsset] = []
    @Published var isLoadingAlbums: Bool = false
    @Published var isLoadingAllAssets: Bool = false
    @Published var error: GalleryError? = nil
    @Published var searchQuery: String = ""
    @Published var activeFilters: GalleryFilters = .default

    private let service: GalleryService
    private let settingsStore: SettingsStore

    private var assetCache: [String: [RemoteAsset]] = [:]
    private var subfolderCache: [String: [RemoteAlbum]] = [:]
    private let thumbnailMemoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 100 * 1024 * 1024 // ~100 MB
        cache.countLimit = 1000
        return cache
    }()
    private var thumbnailTasks: [String: Task<Data?, Never>] = [:]

    init(service: GalleryService, settingsStore: SettingsStore) {
        self.service = service
        self.settingsStore = settingsStore
    }

    var isConfigured: Bool {
        settingsStore.isConfigured
    }

    private var connection: GalleryConnection? {
        guard settingsStore.isConfigured else { return nil }
        return GalleryConnection(
            host: settingsStore.host,
            sharePath: settingsStore.sharePath,
            credentials: settingsStore.credentials
        )
    }

    // MARK: - Albums

    func loadAlbums() async {
        guard let connection = connection else {
            error = .notConfigured
            albums = []
            return
        }

        isLoadingAlbums = true
        error = nil
        defer { isLoadingAlbums = false }

        do {
            let initial = try await service.listAlbums(connection: connection)
            albums = initial

            await withTaskGroup(of: (Int, RemoteAlbum).self) { group in
                for (idx, album) in initial.enumerated() {
                    group.addTask { [service] in
                        let enriched = await service.enrichAlbum(album, connection: connection)
                        return (idx, enriched)
                    }
                }
                for await (idx, enriched) in group {
                    if idx < albums.count, albums[idx].path == enriched.path {
                        albums[idx] = enriched
                    }
                }
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = mapError(error)
        }
    }

    // MARK: - Folder Listing

    func loadFolder(at path: String) async -> GalleryService.FolderListing? {
        guard let connection = connection else {
            error = .notConfigured
            return nil
        }
        do {
            let listing = try await service.listFolder(at: path, connection: connection)
            assetCache[path] = listing.assets
            subfolderCache[path] = listing.subfolders
            return listing
        } catch is CancellationError {
            return nil
        } catch {
            self.error = mapError(error)
            return nil
        }
    }

    func cachedAssets(for path: String) -> [RemoteAsset] {
        assetCache[path] ?? []
    }

    func cachedSubfolders(for path: String) -> [RemoteAlbum] {
        subfolderCache[path] ?? []
    }

    // MARK: - Thumbnails

    func coverThumbnail(for album: RemoteAlbum) async -> Data? {
        if let coverPath = album.coverAssetPath {
            let asset = RemoteAsset(remotePath: coverPath, size: 0, modifiedAt: .distantPast)
            if asset.mediaType != .unknown {
                return await thumbnail(for: asset)
            }
        }
        guard let connection = connection else { return nil }
        do {
            let listing = try await service.listFolder(at: album.path, connection: connection)
            if let first = listing.assets.first {
                return await thumbnail(for: first)
            }
            for sub in listing.subfolders {
                if let data = await coverThumbnail(for: sub) {
                    return data
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    func thumbnail(for asset: RemoteAsset) async -> Data? {
        let cacheKey = asset.remotePath as NSString
        if let data = thumbnailMemoryCache.object(forKey: cacheKey) as Data? {
            return data
        }
        if let existing = thumbnailTasks[asset.remotePath] {
            return await existing.value
        }
        guard let connection = connection else { return nil }

        let task = Task<Data?, Never> { [service] in
            do {
                let data = try await service.thumbnail(for: asset, connection: connection)
                return data
            } catch {
                return nil
            }
        }
        thumbnailTasks[asset.remotePath] = task
        let data = await task.value
        thumbnailTasks[asset.remotePath] = nil
        if let data = data {
            thumbnailMemoryCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
        }
        return data
    }

    func cancelThumbnail(for asset: RemoteAsset) {
        thumbnailTasks[asset.remotePath]?.cancel()
        thumbnailTasks[asset.remotePath] = nil
    }

    // MARK: - Full Resolution

    func downloadFullResolution(_ asset: RemoteAsset) async throws -> URL {
        guard let connection = connection else { throw GalleryError.notConfigured }
        return try await service.downloadFullResolution(for: asset, connection: connection)
    }

    func fullResolutionData(for asset: RemoteAsset) async -> Data? {
        guard let connection = connection else { return nil }
        do {
            return try await service.fullResolutionData(for: asset, connection: connection)
        } catch {
            return nil
        }
    }

    // MARK: - All Assets (Mediathek)

    func loadAllAssets() async {
        guard let connection = connection else {
            error = .notConfigured
            return
        }
        isLoadingAllAssets = true
        defer { isLoadingAllAssets = false }
        do {
            let result = try await service.listAllAssets(connection: connection)
            allAssets = result
        } catch is CancellationError {
            return
        } catch {
            self.error = mapError(error)
        }
    }

    // MARK: - Delete

    func delete(_ asset: RemoteAsset) async throws {
        guard let connection = connection else { throw GalleryError.notConfigured }
        do {
            try await service.delete(asset, connection: connection)
        } catch {
            throw GalleryError.deleteFailed(error.localizedDescription)
        }
        for (path, assets) in assetCache {
            assetCache[path] = assets.filter { $0.remotePath != asset.remotePath }
        }
        allAssets.removeAll { $0.remotePath == asset.remotePath }
        thumbnailMemoryCache.removeObject(forKey: asset.remotePath as NSString)
    }

    // MARK: - Filtering & Search

    func filteredAssets(_ assets: [RemoteAsset]) -> [RemoteAsset] {
        let query = searchQuery.trimmed.lowercased()
        return assets.filter { asset in
            if !query.isEmpty {
                if !asset.filename.lowercased().contains(query) &&
                   !asset.remotePath.lowercased().contains(query) {
                    return false
                }
            }
            return activeFilters.matches(asset)
        }
    }

    func filteredAlbums(_ albums: [RemoteAlbum]) -> [RemoteAlbum] {
        let query = searchQuery.trimmed.lowercased()
        guard !query.isEmpty else { return albums }
        return albums.filter { $0.name.lowercased().contains(query) }
    }

    // MARK: - State Reset

    func resetSearchAndFilters() {
        searchQuery = ""
        activeFilters = .default
    }

    func dismissError() {
        error = nil
    }

    // MARK: - Helpers

    private func mapError(_ error: Error) -> GalleryError {
        if let smb = error as? SMBClientError {
            switch smb {
            case .notConfigured: return .notConfigured
            case .unavailable: return .connectionFailed(smb.localizedDescription)
            case .timedOut: return .connectionFailed(smb.localizedDescription)
            case .connectionFailed(let inner): return .connectionFailed(inner.localizedDescription)
            case .uploadFailed(let inner): return .loadFailed(inner.localizedDescription)
            }
        }
        return .loadFailed(error.localizedDescription)
    }
}
