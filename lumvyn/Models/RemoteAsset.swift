import Foundation

enum RemoteMediaType: String, Codable, Sendable {
    case photo
    case video
    case unknown

    static func from(filename: String) -> RemoteMediaType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "heic", "heif", "png", "webp", "gif", "tiff", "bmp":
            return .photo
        case "mp4", "mov", "m4v":
            return .video
        default:
            return .unknown
        }
    }
}

struct RemoteAsset: Identifiable, Hashable, Sendable {
    let id: String
    let filename: String
    let remotePath: String
    let size: Int64
    let modifiedAt: Date
    let mediaType: RemoteMediaType
    var isBackedUp: Bool

    init(remotePath: String, size: Int64, modifiedAt: Date, isBackedUp: Bool = false) {
        self.remotePath = remotePath
        self.id = remotePath
        self.filename = (remotePath as NSString).lastPathComponent
        self.size = size
        self.modifiedAt = modifiedAt
        self.mediaType = RemoteMediaType.from(filename: (remotePath as NSString).lastPathComponent)
        self.isBackedUp = isBackedUp
    }

    var displayName: String {
        let stem = (filename as NSString).deletingPathExtension
        // Hide UUID-style stems (e.g. "550E8400-E29B-41D4-A716-446655440000") behind a date-based label.
        let uuidPattern = #/^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/#
        if (try? uuidPattern.wholeMatch(in: stem)) != nil {
            let date = DateFormatter.localizedString(from: modifiedAt, dateStyle: .medium, timeStyle: .short)
            return "\(date) · \(mediaType.displayName)"
        }
        return filename
    }
}

extension RemoteMediaType {
    init(legacyString: String) {
        let normalized = legacyString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized == RemoteMediaType.photo.rawValue || normalized.contains("photo") || normalized.contains("foto") || normalized.contains("bild") || normalized.contains("image") {
            self = .photo
            return
        }
        if normalized == RemoteMediaType.video.rawValue || normalized.contains("video") || normalized.contains("film") || normalized.contains("mov") || normalized.contains("mp4") {
            self = .video
            return
        }
        self = .unknown
    }

    var displayName: String {
        switch self {
        case .photo: return NSLocalizedString("media.photo", comment: "")
        case .video: return NSLocalizedString("media.video", comment: "")
        case .unknown: return NSLocalizedString("media.file", comment: "")
        }
    }

    var isVideo: Bool {
        self == .video
    }
}

struct RemoteAlbum: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    var assetCount: Int
    var latestModified: Date?
    var coverAssetPath: String?
    var hasSubfolders: Bool

    init(name: String, path: String, assetCount: Int = 0, latestModified: Date? = nil, coverAssetPath: String? = nil, hasSubfolders: Bool = false) {
        self.name = name
        self.path = path
        self.id = path
        self.assetCount = assetCount
        self.latestModified = latestModified
        self.coverAssetPath = coverAssetPath
        self.hasSubfolders = hasSubfolders
    }
}
