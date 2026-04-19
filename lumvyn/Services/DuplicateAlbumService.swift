import Foundation
import Photos
import CryptoKit
import ImageIO
import CoreGraphics
import os

private let duplicateLogger = Logger(subsystem: "tasio.lumvyn", category: "DuplicateAlbumService")

enum DuplicateAlbumError: Error {
    case authorizationDenied
    case albumCreationFailed
    case missingResource
}

/// Service that scans the photo library for identical assets (by file-byte SHA256
/// and an image-normalized SHA256) and places duplicates into a dedicated album.
final class DuplicateAlbumService {
    static let shared = DuplicateAlbumService()

    private let defaultAlbumName = "doublecat"
    private let concurrency: Int

    init(concurrency: Int = 4) {
        self.concurrency = max(1, concurrency)
    }

    /// Public entry point. Best-effort: returns after attempting the update.
    func scanAndPopulateAlbum(named name: String? = nil) async {
        let albumName = name ?? defaultAlbumName

        do {
            try await ensureAuthorized()
        } catch {
            duplicateLogger.debug("Photo library authorization missing — skipping duplicate scan")
            return
        }

        duplicateLogger.debug("Starting duplicate scan for album: \(albumName)")

        let fetchResult = PHAsset.fetchAssets(with: nil)
        guard fetchResult.count > 0 else {
            duplicateLogger.debug("No assets found in photo library")
            return
        }

        // Thread-safe map for fingerprint -> [localIdentifier]
        var variantMap = [String: [String]]()
        let mapQueue = DispatchQueue(label: "tasio.lumvyn.duplicate.variantMap")

        // Bound concurrency via an async semaphore (actor-based)
        let limiter = AsyncSemaphore(value: concurrency)

        await withTaskGroup(of: (String, [String]?).self) { group in
            for i in 0..<fetchResult.count {
                if Task.isCancelled { break }
                let asset = fetchResult.object(at: i)

                group.addTask {
                    await limiter.wait()
                    var variants: [String]? = nil
                    do {
                        variants = try await Self.computeFingerprints(for: asset)
                    } catch {
                        duplicateLogger.debug("Fingerprint failed for asset \(asset.localIdentifier): \(error.localizedDescription)")
                    }
                    await limiter.signal()
                    return (asset.localIdentifier, variants)
                }
            }

            for await (localId, variants) in group {
                guard let variants = variants else { continue }
                mapQueue.sync {
                    for v in variants {
                        variantMap[v, default: []].append(localId)
                    }
                }
            }
        }

        // Determine duplicates: keep earliest creationDate as canonical
        var duplicateIDs = Set<String>()
        for (_, ids) in variantMap where ids.count > 1 {
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            var groupAssets: [PHAsset] = []
            fetch.enumerateObjects { asset, _, _ in groupAssets.append(asset) }

            groupAssets.sort { a, b in
                let ta = a.creationDate?.timeIntervalSince1970 ?? Double.greatestFiniteMagnitude
                let tb = b.creationDate?.timeIntervalSince1970 ?? Double.greatestFiniteMagnitude
                return ta < tb
            }

            if groupAssets.count > 1 {
                let dup = groupAssets.dropFirst().map { $0.localIdentifier }
                duplicateIDs.formUnion(dup)
            }
        }

        guard !duplicateIDs.isEmpty else {
            duplicateLogger.debug("No duplicates found")
            return
        }

        duplicateLogger.debug("Found \(duplicateIDs.count) duplicates — updating album \(albumName)")

        do {
            let collection = try await getOrCreateAlbum(named: albumName)
            let assetsToAdd = PHAsset.fetchAssets(withLocalIdentifiers: Array(duplicateIDs), options: nil)
            try await replaceAssets(in: collection, with: assetsToAdd)
            duplicateLogger.debug("Updated album \(albumName) with \(duplicateIDs.count) assets")
        } catch {
            duplicateLogger.error("Failed to update duplicate album: \(error.localizedDescription)")
        }
    }

    // MARK: - Authorization

    private func ensureAuthorized() async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited { return }

        let newStatus = await withCheckedContinuation { (cont: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }

        guard newStatus == .authorized || newStatus == .limited else {
            throw DuplicateAlbumError.authorizationDenied
        }
    }

    // MARK: - Album helpers

    private func getOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", name)
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        if let existing = fetch.firstObject { return existing }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PHAssetCollection, Error>) in
            var localId: String? = nil
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                localId = req.placeholderForCreatedAssetCollection.localIdentifier
            }, completionHandler: { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let id = localId else {
                    cont.resume(throwing: DuplicateAlbumError.albumCreationFailed)
                    return
                }
                let collFetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
                if let coll = collFetch.firstObject {
                    cont.resume(returning: coll)
                } else {
                    cont.resume(throwing: DuplicateAlbumError.albumCreationFailed)
                }
            })
        }
    }

    private func replaceAssets(in collection: PHAssetCollection, with assets: PHFetchResult<PHAsset>) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                if let req = PHAssetCollectionChangeRequest(for: collection) {
                    let current = PHAsset.fetchAssets(in: collection, options: nil)
                    if current.count > 0 { req.removeAssets(current) }
                    req.addAssets(assets)
                }
            }, completionHandler: { success, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: ())
            })
        }
    }

    // MARK: - Fingerprinting (copied from DeduplicationService — non-actor helper)

    private static func computeFingerprints(for asset: PHAsset) async throws -> [String] {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { throw DuplicateAlbumError.missingResource }

        let resource: PHAssetResource
        if let preferred = resources.first(where: { $0.type == .fullSizePhoto || $0.type == .photo || $0.type == .fullSizeVideo || $0.type == .video }) {
            resource = preferred
        } else {
            resource = resources[0]
        }

        let fileHex: String = try await computeFileHash(for: resource)
        var variants: [String] = [fileHex]

        if asset.mediaType == .image {
            if let imgHex = try await computeImageHash(for: asset) {
                variants.append(imgHex)
            }
        }

        return variants
    }

    private static func computeFileHash(for resource: PHAssetResource) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            var hasher = SHA256()
            let opts = PHAssetResourceRequestOptions()
            opts.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().requestData(for: resource, options: opts, dataReceivedHandler: { data in
                hasher.update(data: data)
            }, completionHandler: { error in
                if let error = error { cont.resume(throwing: error); return }
                let hex = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                cont.resume(returning: hex)
            })
        }
    }

    private static func computeImageHash(for asset: PHAsset) async throws -> String? {
        let data: Data? = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data?, Error>) in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .highQualityFormat
            opts.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, info in
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                cont.resume(returning: data)
            }
        }

        guard let data = data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let thumbOpts = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts) ?? CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height

        guard totalBytes > 0 else { return nil }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
        defer { buffer.deallocate() }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        guard let ctx = CGContext(data: buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        let pixelData = Data(bytes: buffer, count: totalBytes)
        let digest = SHA256.hash(data: pixelData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Reuse shared `AsyncSemaphore` actor defined elsewhere in the module.
