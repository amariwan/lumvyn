import CryptoKit
import Foundation
import Photos
import os
import ImageIO
import CoreGraphics

private let dedupLogger = Logger(subsystem: "tasio.lumvyn", category: "DeduplicationService")

public enum DeduplicationError: LocalizedError {
    case noResource
    case hashingFailed

    public var errorDescription: String? {
        switch self {
        case .noResource:
            return NSLocalizedString("Keine Asset-Ressource zum Hashen gefunden.", comment: "")
        case .hashingFailed:
            return NSLocalizedString("Hashing des Assets fehlgeschlagen.", comment: "")
        }
    }
}

public actor DeduplicationService {
    private let storageURL: URL
    private var knownFingerprints: Set<String> = []

    private var isLoaded = false
    private var loadTask: Task<Void, Never>?
    private let persistQueue = DispatchQueue(label: "tasio.lumvyn.dedup.persist", qos: .utility)

    public init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let caches =
                FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageURL = caches.appendingPathComponent("dedup.json")
        }
    }

    private func ensureLoaded() async {
        if isLoaded { return }

        if let task = loadTask {
            await task.value
            return
        }

        let storageCopy = storageURL
        let detached = Task.detached { () -> Set<String> in
            guard FileManager.default.fileExists(atPath: storageCopy.path) else { return Set<String>() }
            do {
                let data = try Data(contentsOf: storageCopy)
                let array = try JSONDecoder().decode([String].self, from: data)
                return Set(array)
            } catch {
                dedupLogger.error("Dedup load error: \(error.localizedDescription)")
                return Set<String>()
            }
        }

        let task = Task {
            defer { isLoaded = true }
            let result = await detached.value
            await self.replaceKnownFingerprints(result)
        }

        loadTask = task
        await task.value
        loadTask = nil
    }

    public func contains(_ fingerprint: String) async -> Bool {
        await ensureLoaded()
        return knownFingerprints.contains(fingerprint)
    }

    public func markUploaded(fingerprint: String) async {
        await ensureLoaded()

        let (inserted, _) = knownFingerprints.insert(fingerprint)
        if inserted {
            dedupLogger.debug("Marked uploaded fingerprint: \(fingerprint)")
            persistKnownFingerprints()
        } else {
            dedupLogger.debug("Fingerprint already known: \(fingerprint)")
        }
    }

    private func persistKnownFingerprints() {
        let snapshot = knownFingerprints.sorted()
        let storageCopy = storageURL

        persistQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: storageCopy, options: [.atomic])
                dedupLogger.debug("Persisted \(snapshot.count) fingerprints to \(storageCopy.path)")
            } catch {
                dedupLogger.error("Dedup persist error: \(error.localizedDescription)")
            }
        }
    }

    private func replaceKnownFingerprints(_ newSet: Set<String>) {
        knownFingerprints = newSet
        dedupLogger.debug("Loaded \(newSet.count) known fingerprints")
    }

    /// Returns one or more fingerprint variants for an asset.
    /// The first element is always the file-byte SHA256. For image assets a second
    /// element is appended containing a normalized-pixel SHA256 (thumbnail rendered
    /// with transform applied). This helps detect visually identical images that
    /// differ only in container/metadata.
    public func fingerprints(for asset: PHAsset) async throws -> [String] {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { throw DeduplicationError.noResource }

        let resource: PHAssetResource
        if let preferred = resources.first(where: { $0.type == .fullSizePhoto || $0.type == .photo || $0.type == .fullSizeVideo || $0.type == .video }) {
            resource = preferred
        } else {
            resource = resources.first!
        }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString)_\(resource.originalFilename)")
        try? FileManager.default.removeItem(at: tmpURL)

        let resourceOptions = PHAssetResourceRequestOptions()
        resourceOptions.isNetworkAccessAllowed = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: tmpURL, options: resourceOptions) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return try await Task.detached(priority: .utility) {
            defer { try? FileManager.default.removeItem(at: tmpURL) }

            var variants: [String] = []

            // 1) file-byte SHA256
            do {
                guard let stream = InputStream(url: tmpURL) else {
                    throw DeduplicationError.hashingFailed
                }

                stream.open()
                defer { stream.close() }

                var context = SHA256()
                let bufferSize = 64 * 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }

                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read < 0 { throw DeduplicationError.hashingFailed }
                    if read == 0 { break }
                    context.update(data: Data(bytes: buffer, count: read))
                }

                let fileHex = context.finalize().map { String(format: "%02x", $0) }.joined()
                variants.append(fileHex)
                dedupLogger.debug("Computed file fingerprint for asset \(asset.localIdentifier): \(fileHex)")
            } catch {
                dedupLogger.error("File hashing failed for asset \(asset.localIdentifier): \(error.localizedDescription)")
                throw error
            }

            // 2) normalized pixel SHA256 for images (best-effort)
            if asset.mediaType == .image {
                do {
                    if let source = CGImageSourceCreateWithURL(tmpURL as CFURL, nil) {
                        let thumbOpts = [
                            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                            kCGImageSourceThumbnailMaxPixelSize: 512,
                            kCGImageSourceCreateThumbnailWithTransform: true
                        ] as CFDictionary

                        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts) ?? CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                            throw DeduplicationError.hashingFailed
                        }

                        let width = cgImage.width
                        let height = cgImage.height
                        let bytesPerPixel = 4
                        let bytesPerRow = bytesPerPixel * width
                        let totalBytes = bytesPerRow * height

                        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: totalBytes)
                        defer { buffer.deallocate() }

                        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
                        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

                        guard let ctx = CGContext(data: buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
                            throw DeduplicationError.hashingFailed
                        }

                        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

                        let data = Data(bytes: buffer, count: totalBytes)
                        let imgHex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                        variants.append(imgHex)
                        dedupLogger.debug("Computed image fingerprint for asset \(asset.localIdentifier): \(imgHex)")
                    }
                } catch {
                    dedupLogger.debug("Image fingerprinting failed for asset \(asset.localIdentifier): \(error.localizedDescription)")
                }
            }

            return variants
        }.value
    }

    public func fingerprint(for asset: PHAsset) async throws -> String {
        let fps = try await fingerprints(for: asset)
        guard let first = fps.first else { throw DeduplicationError.hashingFailed }
        return first
    }
}
