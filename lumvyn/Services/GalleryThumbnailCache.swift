import CryptoKit
import Foundation
import os

private let cacheLogger = Logger(subsystem: "tasio.lumvyn", category: "GalleryThumbnailCache")

actor GalleryThumbnailCache {
    private let directory: URL
    private let maxSizeBytes: Int64
    private var index: [String: Entry] = [:]
    private var totalSizeBytes: Int64 = 0
    private var loaded = false

    private struct Entry {
        let size: Int64
        var lastUsed: Date
    }

    init(maxSizeBytes: Int64 = 500 * 1024 * 1024) {
        self.maxSizeBytes = maxSizeBytes
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = caches.appendingPathComponent("GalleryThumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for remotePath: String) -> Data? {
        loadIndexIfNeeded()
        let key = Self.cacheKey(for: remotePath)
        let url = directory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if var entry = index[key] {
            entry.lastUsed = Date()
            index[key] = entry
        }
        return data
    }

    func store(_ data: Data, for remotePath: String) {
        loadIndexIfNeeded()
        let key = Self.cacheKey(for: remotePath)
        let url = directory.appendingPathComponent(key)
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
            cacheLogger.error("Cache write failed: \(error.localizedDescription)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        index.removeAll()
        totalSizeBytes = 0
    }

    static func cacheKey(for remotePath: String) -> String {
        let digest = SHA256.hash(data: Data(remotePath.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadIndexIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var total: Int64 = 0
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate ?? Date.distantPast
            index[url.lastPathComponent] = Entry(size: size, lastUsed: modified)
            total += size
        }
        totalSizeBytes = total
    }

    private func evictIfNeeded() {
        guard totalSizeBytes > maxSizeBytes else { return }
        let sorted = index.sorted { $0.value.lastUsed < $1.value.lastUsed }
        for (key, entry) in sorted {
            if totalSizeBytes <= maxSizeBytes { break }
            let url = directory.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: url)
            index.removeValue(forKey: key)
            totalSizeBytes -= entry.size
        }
    }
}
