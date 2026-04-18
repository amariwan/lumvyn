import CryptoKit
import Foundation
import os

private let cacheLogger = Logger(subsystem: "tasio.lumvyn", category: "GalleryThumbnailCache")

actor GalleryThumbnailCache {
    private let directory: URL
    private let maxSizeBytes: Int64
    private var index: [String: Entry] = [:]
    private var totalSizeBytes: Int64 = 0
    private var isIndexLoaded = false
    private let fileManager = FileManager.default

    private struct Entry {
        let size: Int64
        var lastUsed: Date
    }

    init(maxSizeBytes: Int64 = 500 * 1024 * 1024) {
        self.maxSizeBytes = maxSizeBytes
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directory = caches.appendingPathComponent("GalleryThumbnails", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            cacheLogger.warning("Failed to create cache directory: \(error.localizedDescription)")
        }
    }

    func data(for remotePath: String) async -> Data? {
        loadIndexIfNeeded()
        let key = Self.cacheKey(for: remotePath)
        let url = directory.appendingPathComponent(key)
        let data: Data?
        do {
            data = try await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
        } catch {
            return nil
        }
        if let data = data {
            if var entry = index[key] {
                entry.lastUsed = Date()
                index[key] = entry
            } else {
                // If the file exists on disk but wasn't indexed (e.g. load failed earlier), add it now
                let size = Int64(data.count)
                index[key] = Entry(size: size, lastUsed: Date())
                totalSizeBytes += size
            }
        }
        return data
    }

    func store(_ data: Data, for remotePath: String) {
        loadIndexIfNeeded()
        let key = Self.cacheKey(for: remotePath)
        let url = directory.appendingPathComponent(key)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            cacheLogger.warning("Ensure cache directory failed: \(error.localizedDescription)")
        }

        do {
            try data.write(to: url, options: [.atomic])
            if let existing = index[key] {
                totalSizeBytes -= existing.size
            }
            let size = Int64(data.count)
            index[key] = Entry(size: size, lastUsed: Date())
            totalSizeBytes += size
            evictIfNeeded()
        } catch {
            cacheLogger.error("Cache write failed for \(key): \(error.localizedDescription)")
        }
    }

    func clear() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        index.removeAll()
        totalSizeBytes = 0
        isIndexLoaded = true
    }

    static func cacheKey(for remotePath: String) -> String {
        let digest = SHA256.hash(data: Data(remotePath.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadIndexIfNeeded() {
        guard !isIndexLoaded else { return }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            cacheLogger.warning("Failed to create cache directory: \(error.localizedDescription)")
        }

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var total: Int64 = 0
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate ?? Date.distantPast
            index[url.lastPathComponent] = Entry(size: size, lastUsed: modified)
            total += size
        }
        totalSizeBytes = total
        isIndexLoaded = true
    }

    private func evictIfNeeded() {
        guard totalSizeBytes > maxSizeBytes else { return }
        let sorted = index.sorted { $0.value.lastUsed < $1.value.lastUsed }
        for (key, entry) in sorted {
            if totalSizeBytes <= maxSizeBytes { break }
            let url = directory.appendingPathComponent(key)
            do {
                try fileManager.removeItem(at: url)
            } catch {
                cacheLogger.warning("Failed to remove cached thumbnail \(key): \(error.localizedDescription)")
            }
            index.removeValue(forKey: key)
            totalSizeBytes -= entry.size
        }
    }
}
