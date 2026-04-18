import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

private let galleryLogger = Logger(subsystem: "tasio.lumvyn", category: "GalleryService")

struct GalleryConnection: Sendable {
    let host: String
    let sharePath: String
    let credentials: SMBCredentials?

    var shareName: String {
        let trimmed = sharePath.trimmingCharacters(in: .init(charactersIn: "/"))
        if let idx = trimmed.firstIndex(of: "/") {
            return String(trimmed[..<idx])
        }
        return trimmed
    }

    var basePath: String {
        let trimmed = sharePath.trimmingCharacters(in: .init(charactersIn: "/"))
        if let idx = trimmed.firstIndex(of: "/") {
            return String(trimmed[trimmed.index(after: idx)...])
        }
        return ""
    }

    func resolvedPath(_ relative: String) -> String {
        let base = basePath
        if base.isEmpty { return relative }
        if relative.isEmpty { return base }
        return base + "/" + relative
    }
}

final class GalleryService: @unchecked Sendable {
    private let smbClient: any SMBClientProtocol
    private let cache: GalleryThumbnailCache
    private let remoteIndex: RemoteIndexStore
    private let thumbnailSemaphore = AsyncSemaphore(value: 5)
    private let thumbnailMaxPixels: Int = 400

    init(
        smbClient: any SMBClientProtocol,
        cache: GalleryThumbnailCache,
        remoteIndex: RemoteIndexStore
    ) {
        self.smbClient = smbClient
        self.cache = cache
        self.remoteIndex = remoteIndex
    }

    // MARK: - Albums

    func listAlbums(connection: GalleryConnection) async throws -> [RemoteAlbum] {
        try Task.checkCancellation()
        let entries = try await smbClient.listDirectoryItems(
            host: connection.host,
            shareName: connection.shareName,
            path: connection.basePath,
            credentials: connection.credentials
        )
        return entries
            .filter { $0.isDirectory }
            .map { entry in
                RemoteAlbum(
                    name: entry.name,
                    path: entry.name,
                    latestModified: entry.modifiedAt
                )
            }
    }

    // MARK: - Subfolders + Assets

    struct FolderListing: Sendable {
        let subfolders: [RemoteAlbum]
        let assets: [RemoteAsset]
    }

    func listFolder(at relativePath: String, connection: GalleryConnection) async throws -> FolderListing {
        try Task.checkCancellation()
        let entries = try await smbClient.listDirectoryItems(
            host: connection.host,
            shareName: connection.shareName,
            path: connection.resolvedPath(relativePath),
            credentials: connection.credentials
        )

        let backedUpPaths = await backedUpRemotePaths(connection: connection)

        var subfolders: [RemoteAlbum] = []
        var assets: [RemoteAsset] = []

        for entry in entries {
            let childRelative = relativePath.isEmpty ? entry.name : "\(relativePath)/\(entry.name)"
            if entry.isDirectory {
                subfolders.append(RemoteAlbum(
                    name: entry.name,
                    path: childRelative,
                    latestModified: entry.modifiedAt
                ))
            } else {
                let mediaType = RemoteMediaType.from(filename: entry.name)
                guard mediaType != .unknown else { continue }
                let absolutePath = connection.resolvedPath(childRelative)
                assets.append(RemoteAsset(
                    remotePath: childRelative,
                    size: entry.size ?? 0,
                    modifiedAt: entry.modifiedAt ?? .distantPast,
                    isBackedUp: backedUpPaths.contains(absolutePath)
                ))
            }
        }

        assets.sort { $0.modifiedAt > $1.modifiedAt }
        return FolderListing(subfolders: subfolders, assets: assets)
    }

    // MARK: - Album metadata enrichment

    func enrichAlbum(_ album: RemoteAlbum, connection: GalleryConnection) async -> RemoteAlbum {
        do {
            let listing = try await listFolder(at: album.path, connection: connection)
            var enriched = album
            enriched.assetCount = listing.assets.count
            enriched.hasSubfolders = !listing.subfolders.isEmpty
            if let latest = listing.assets.first {
                enriched.coverAssetPath = latest.remotePath
                enriched.latestModified = latest.modifiedAt
            }
            return enriched
        } catch {
            galleryLogger.debug("enrichAlbum failed for \(album.path): \(error.localizedDescription)")
            return album
        }
    }

    // MARK: - Thumbnails

    func thumbnail(for asset: RemoteAsset, connection: GalleryConnection) async throws -> Data {
        if let cached = await cache.data(for: asset.remotePath) {
            return cached
        }

        await thumbnailSemaphore.wait()
        defer { Task { await thumbnailSemaphore.signal() } }

        if let cached = await cache.data(for: asset.remotePath) {
            return cached
        }

        try Task.checkCancellation()

        let absolutePath = connection.resolvedPath(asset.remotePath)
        let localURL = try await smbClient.downloadFile(
            host: connection.host,
            shareName: connection.shareName,
            remotePath: absolutePath,
            credentials: connection.credentials
        )

        defer { try? FileManager.default.removeItem(at: localURL) }

        let pixels = thumbnailMaxPixels
        let mediaType = asset.mediaType
        let data = try await Task.detached(priority: .utility) { () throws -> Data in
            switch mediaType {
            case .photo:
                return try Self.makeImageThumbnail(at: localURL, maxPixel: pixels)
            case .video:
                return try await Self.makeVideoThumbnail(at: localURL, maxPixel: pixels)
            case .unknown:
                throw GalleryError.loadFailed("Unsupported media type")
            }
        }.value

        await cache.store(data, for: asset.remotePath)
        return data
    }

    // MARK: - Full resolution

    func downloadFullResolution(for asset: RemoteAsset, connection: GalleryConnection) async throws -> URL {
        try Task.checkCancellation()
        let absolutePath = connection.resolvedPath(asset.remotePath)
        return try await smbClient.downloadFile(
            host: connection.host,
            shareName: connection.shareName,
            remotePath: absolutePath,
            credentials: connection.credentials
        )
    }

    func fullResolutionData(for asset: RemoteAsset, connection: GalleryConnection) async throws -> Data {
        let url = try await downloadFullResolution(for: asset, connection: connection)
        defer { try? FileManager.default.removeItem(at: url) }
        return try Data(contentsOf: url)
    }

    // MARK: - Recursive asset enumeration

    func listAllAssets(connection: GalleryConnection, maxDepth: Int = 4) async throws -> [RemoteAsset] {
        var collected: [RemoteAsset] = []
        try await walk(relativePath: "", depth: 0, maxDepth: maxDepth, connection: connection, into: &collected)
        collected.sort { $0.modifiedAt > $1.modifiedAt }
        return collected
    }

    private func walk(
        relativePath: String,
        depth: Int,
        maxDepth: Int,
        connection: GalleryConnection,
        into collected: inout [RemoteAsset]
    ) async throws {
        try Task.checkCancellation()
        guard depth <= maxDepth else { return }
        let listing = try await listFolder(at: relativePath, connection: connection)
        collected.append(contentsOf: listing.assets)
        for sub in listing.subfolders {
            try await walk(
                relativePath: sub.path,
                depth: depth + 1,
                maxDepth: maxDepth,
                connection: connection,
                into: &collected
            )
        }
    }

    // MARK: - Delete

    func delete(_ asset: RemoteAsset, connection: GalleryConnection) async throws {
        try Task.checkCancellation()
        let resolvedPath = connection.resolvedPath(asset.remotePath)
        try await smbClient.deleteRemoteItem(
            host: connection.host,
            sharePath: connection.sharePath,
            remotePath: resolvedPath,
            credentials: connection.credentials
        )

        let mappings = await remoteIndex.allMappings()
        for (localId, entry) in mappings
        where entry.host == connection.host
            && entry.sharePath == connection.sharePath
            && entry.remotePath == resolvedPath {
            await remoteIndex.removeMapping(localId: localId)
        }
    }

    // MARK: - Helpers

    private func backedUpRemotePaths(connection: GalleryConnection) async -> Set<String> {
        let mappings = await remoteIndex.allMappings()
        var paths: Set<String> = []
        for entry in mappings.values where entry.host == connection.host && entry.sharePath == connection.sharePath {
            paths.insert(entry.remotePath)
        }
        return paths
    }

    private static func makeImageThumbnail(at url: URL, maxPixel: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw GalleryError.loadFailed("Image decode failed")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw GalleryError.loadFailed("Thumbnail creation failed")
        }
        return try encodeJPEG(thumb)
    }

    private static func makeVideoThumbnail(at url: URL, maxPixel: Int) async throws -> Data {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)

        return try await awaitThumbnail(from: generator, at: time)
    }

    private static func awaitThumbnail(from generator: AVAssetImageGenerator, at time: CMTime) async throws -> Data {
        var gen: AVAssetImageGenerator? = generator
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let times = [NSValue(time: time)]
                gen?.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, actualTime, result, error in
                    switch result {
                    case .succeeded:
                        if let image = cgImage {
                            do {
                                let data = try encodeJPEG(image)
                                continuation.resume(returning: data)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        } else {
                            continuation.resume(throwing: GalleryError.loadFailed("Thumbnail image missing"))
                        }
                    case .failed:
                        continuation.resume(throwing: error ?? GalleryError.loadFailed("Thumbnail generation failed"))
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    @unknown default:
                        continuation.resume(throwing: GalleryError.loadFailed("Unknown thumbnail generation result"))
                    }
                }
            }
        } onCancel: {
            gen?.cancelAllCGImageGeneration()
        }
    }

    private static func encodeJPEG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw GalleryError.loadFailed("JPEG encoder unavailable")
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.75]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw GalleryError.loadFailed("JPEG encode failed")
        }
        return data as Data
    }
}

actor AsyncSemaphore {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.available = value
    }

    func wait() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            available += 1
        }
    }
}
