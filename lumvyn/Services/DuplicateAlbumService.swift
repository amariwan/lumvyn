import Foundation
import Photos
import os

private let duplicateLogger = Logger(subsystem: "tasio.lumvyn", category: "DuplicateAlbumService")

/// Scans the photo library for duplicate assets (by file-byte SHA256 and, for images,
/// a normalized pixel SHA256) and places duplicates into a dedicated album named
/// `doublecat` (or a custom name). This is a best-effort operation and can be
/// expensive for large libraries — it's intended to run on a background queue.
@MainActor
final class DuplicateAlbumService {
    static let shared = DuplicateAlbumService()

    private let defaultAlbumName = "doublecat"
    private let dedup = DeduplicationService()

    private init() {}

    func scanAndPopulateAlbum(named name: String? = nil) async {
        let albumName = name ?? defaultAlbumName

        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
                PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else {
            duplicateLogger.debug("Photo library authorization missing — skipping duplicate scan")
            return
        }

        duplicateLogger.debug("Starting duplicate scan for album: \(albumName)")

        let fetchResult = PHAsset.fetchAssets(with: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in assets.append(asset) }

        var variantMap: [String: [String]] = [:] // fingerprint -> [localIdentifier]

        for asset in assets {
            do {
                let variants = try await dedup.fingerprints(for: asset)
                for v in variants {
                    var arr = variantMap[v] ?? []
                    arr.append(asset.localIdentifier)
                    variantMap[v] = arr
                }
            } catch {
                duplicateLogger.debug("Failed to fingerprint asset \(asset.localIdentifier): \(error.localizedDescription)")
            }
        }

        var duplicateIDs = Set<String>()
        for (_, ids) in variantMap where ids.count > 1 {
            duplicateIDs.formUnion(ids)
        }

        guard !duplicateIDs.isEmpty else {
            duplicateLogger.debug("No duplicates found")
            // Optionally clear existing album contents — skip for safety
            return
        }

        duplicateLogger.debug("Found \(duplicateIDs.count) assets considered duplicates — updating album \(albumName)")

        do {
            let collection = try await getOrCreateAlbum(named: albumName)

            let idsArray = Array(duplicateIDs)
            let assetsToAdd = PHAsset.fetchAssets(withLocalIdentifiers: idsArray, options: nil)

            try await replaceAssets(in: collection, with: assetsToAdd)
            duplicateLogger.debug("Updated album \(albumName) with \(idsArray.count) assets")
        } catch {
            duplicateLogger.error("Failed to update duplicate album: \(error.localizedDescription)")
        }
    }

    private func getOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        // Check existing collections
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", name)
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        if let existing = fetch.firstObject {
            return existing
        }

        return try await withCheckedThrowingContinuation { cont in
            var localId: String? = nil
            PHPhotoLibrary.shared().performChanges({
                let createReq = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                localId = createReq.placeholderForCreatedAssetCollection?.localIdentifier
            }, completionHandler: { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let id = localId {
                    let collFetch = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil)
                    if let coll = collFetch.firstObject {
                        cont.resume(returning: coll)
                    } else {
                        cont.resume(throwing: NSError(domain: "DuplicateAlbumService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created album"]))
                    }
                } else {
                    cont.resume(throwing: NSError(domain: "DuplicateAlbumService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unknown album creation error"]))
                }
            })
        }
    }

    private func replaceAssets(in collection: PHAssetCollection, with assets: PHFetchResult<PHAsset>) async throws {
        try await withCheckedThrowingContinuation { cont in
            PHPhotoLibrary.shared().performChanges({
                if let req = PHAssetCollectionChangeRequest(for: collection) {
                    let current = PHAsset.fetchAssets(in: collection, options: nil)
                    if current.count > 0 {
                        req.removeAssets(current)
                    }
                    req.addAssets(assets)
                }
            }, completionHandler: { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            })
        }
    }
}
