import Foundation

actor RemoteIndexStore {
    struct Entry: Codable {
        let host: String
        let sharePath: String
        let remotePath: String
        let fingerprint: String?
        let uploadedAt: Date
    }

    private var map: [String: Entry] = [:]
    private let fileURL: URL

    init(fileName: String = "remote-index.json") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("lumvyn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                self.map = try JSONDecoder().decode([String: Entry].self, from: data)
            } catch {
                NSLog("RemoteIndexStore load error: %@", String(describing: error))
            }
        }
    }

    func saveMapping(localId: String, host: String, sharePath: String, remotePath: String, fingerprint: String?) async {
        map[localId] = Entry(host: host, sharePath: sharePath, remotePath: remotePath, fingerprint: fingerprint, uploadedAt: Date())
        persistToDisk()
    }

    func removeMapping(localId: String) async {
        map.removeValue(forKey: localId)
        persistToDisk()
    }

    func mapping(for localId: String) -> Entry? {
        map[localId]
    }

    func allLocalIdentifiers() -> [String] {
        Array(map.keys)
    }

    func allMappings() -> [String: Entry] {
        map
    }

    // MARK: - Persistence

    private func persistToDisk() {
        let snapshot = map
        let fileURLCopy = fileURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: fileURLCopy, options: [.atomic])
            } catch {
                NSLog("RemoteIndexStore persist error: %@", String(describing: error))
            }
        }
    }

}
