import Foundation

enum UploadStatus: String, Codable, CaseIterable {
    case pending
    case uploading
    case done
    case failed

    var displayName: String {
        switch self {
        case .pending: return NSLocalizedString("Ausstehend", comment: "Upload status: pending")
        case .uploading: return NSLocalizedString("Aktiv", comment: "Upload status: uploading/active")
        case .done: return NSLocalizedString("Fertig", comment: "Upload status: done")
        case .failed: return NSLocalizedString("Fehler", comment: "Upload status: failed")
        }
    }
}

struct UploadItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let assetLocalIdentifier: String
    let fileName: String
    let mediaType: RemoteMediaType
    let createdAt: Date
    var albumName: String?
    var locationName: String?
    var isFavorite: Bool
    var isHidden: Bool
    var pixelWidth: Int
    var pixelHeight: Int
    var sourceType: String
    var subtypes: [String]
    var burstIdentifier: String?
    var fileSize: Int64?
    var fingerprint: String?
    var priority: Int
    var status: UploadStatus
    var progress: Double
    var retryCount: Int
    var lastError: String?
    var assetDuration: TimeInterval?

    init(
        assetLocalIdentifier: String,
        fileName: String,
        mediaType: String,
        createdAt: Date,
        albumName: String? = nil,
        locationName: String? = nil,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        sourceType: String = "",
        subtypes: [String] = [],
        burstIdentifier: String? = nil,
        fileSize: Int64? = nil,
        fingerprint: String? = nil,
        priority: Int = 0,
        assetDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.assetLocalIdentifier = assetLocalIdentifier
        self.fileName = fileName
        self.mediaType = RemoteMediaType(legacyString: mediaType)
        self.createdAt = createdAt
        self.albumName = albumName
        self.locationName = locationName
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sourceType = sourceType
        self.subtypes = subtypes
        self.burstIdentifier = burstIdentifier
        self.fileSize = fileSize
        self.fingerprint = fingerprint
        self.priority = priority
        self.status = .pending
        self.progress = 0.0
        self.retryCount = 0
        self.lastError = nil
        self.assetDuration = assetDuration
    }

    init(
        id: UUID = UUID(),
        assetLocalIdentifier: String,
        fileName: String,
        mediaType: RemoteMediaType,
        createdAt: Date,
        albumName: String? = nil,
        locationName: String? = nil,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        sourceType: String = "",
        subtypes: [String] = [],
        burstIdentifier: String? = nil,
        fileSize: Int64? = nil,
        fingerprint: String? = nil,
        priority: Int = 0,
        assetDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.assetLocalIdentifier = assetLocalIdentifier
        self.fileName = fileName
        self.mediaType = mediaType
        self.createdAt = createdAt
        self.albumName = albumName
        self.locationName = locationName
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sourceType = sourceType
        self.subtypes = subtypes
        self.burstIdentifier = burstIdentifier
        self.fileSize = fileSize
        self.fingerprint = fingerprint
        self.priority = priority
        self.status = .pending
        self.progress = 0.0
        self.retryCount = 0
        self.lastError = nil
        self.assetDuration = assetDuration
    }

    private enum CodingKeys: String, CodingKey {
        case id, assetLocalIdentifier, fileName, mediaType, createdAt, albumName,
             locationName, isFavorite, isHidden, pixelWidth, pixelHeight,
             sourceType, subtypes, burstIdentifier, fileSize, fingerprint,
             priority, status, progress, retryCount, lastError, assetDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        assetLocalIdentifier = try container.decode(String.self, forKey: .assetLocalIdentifier)
        fileName = try container.decode(String.self, forKey: .fileName)
        let mediaTypeString = try container.decode(String.self, forKey: .mediaType)
        mediaType = RemoteMediaType(legacyString: mediaTypeString)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        albumName = try container.decodeIfPresent(String.self, forKey: .albumName)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        pixelWidth = try container.decode(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decode(Int.self, forKey: .pixelHeight)
        sourceType = try container.decode(String.self, forKey: .sourceType)
        subtypes = try container.decode([String].self, forKey: .subtypes)
        burstIdentifier = try container.decodeIfPresent(String.self, forKey: .burstIdentifier)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        fingerprint = try container.decodeIfPresent(String.self, forKey: .fingerprint)
        priority = try container.decode(Int.self, forKey: .priority)
        status = try container.decode(UploadStatus.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        assetDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .assetDuration)
    }
}
