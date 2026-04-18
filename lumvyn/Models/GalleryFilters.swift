import Foundation

enum GalleryMediaTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case photos
    case videos

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return NSLocalizedString("Alle Medien", comment: "Gallery filter: all media")
        case .photos: return NSLocalizedString("gallery.filter.photos", comment: "")
        case .videos: return NSLocalizedString("gallery.filter.videos", comment: "")
        }
    }
}

enum GalleryBackupFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case backedUp
    case notBackedUp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return NSLocalizedString("Alle Medien", comment: "Gallery filter: all media")
        case .backedUp: return NSLocalizedString("gallery.filter.backedUp", comment: "")
        case .notBackedUp: return NSLocalizedString("gallery.filter.notBackedUp", comment: "")
        }
    }
}

enum GalleryDateRange: String, CaseIterable, Identifiable, Sendable {
    case all
    case last7Days
    case last30Days
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return NSLocalizedString("Gesamter Zeitraum", comment: "")
        case .last7Days: return NSLocalizedString("Letzte 7 Tage", comment: "")
        case .last30Days: return NSLocalizedString("Letzte 30 Tage", comment: "")
        case .custom: return NSLocalizedString("Benutzerdefiniert", comment: "")
        }
    }
}

struct GalleryFilters: Equatable, Sendable {
    var mediaType: GalleryMediaTypeFilter = .all
    var backup: GalleryBackupFilter = .all
    var dateRange: GalleryDateRange = .all
    var customStart: Date? = nil
    var customEnd: Date? = nil

    static let `default` = GalleryFilters()

    var isActive: Bool {
        mediaType != .all || backup != .all || dateRange != .all
    }

    func matches(_ asset: RemoteAsset) -> Bool {
        switch mediaType {
        case .all: break
        case .photos: if asset.mediaType != .photo { return false }
        case .videos: if asset.mediaType != .video { return false }
        }

        switch backup {
        case .all: break
        case .backedUp: if !asset.isBackedUp { return false }
        case .notBackedUp: if asset.isBackedUp { return false }
        }

        if let (start, end) = effectiveDateRange() {
            if asset.modifiedAt < start || asset.modifiedAt > end {
                return false
            }
        }

        return true
    }

    private func effectiveDateRange() -> (Date, Date)? {
        let now = Date()
        let cal = Calendar.current
        switch dateRange {
        case .all:
            return nil
        case .last7Days:
            guard let start = cal.date(byAdding: .day, value: -7, to: now) else { return nil }
            return (start, now)
        case .last30Days:
            guard let start = cal.date(byAdding: .day, value: -30, to: now) else { return nil }
            return (start, now)
        case .custom:
            guard let s = customStart, let e = customEnd else { return nil }
            return (min(s, e), max(s, e))
        }
    }
}

enum GalleryError: LocalizedError, Identifiable, Equatable {
    case notConfigured
    case connectionFailed(String)
    case notFound(String)
    case deleteFailed(String)
    case loadFailed(String)

    var id: String { errorDescription ?? "gallery.error" }

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return NSLocalizedString("gallery.error.noSMB", comment: "")
        case .connectionFailed(let msg):
            return msg.isEmpty ? NSLocalizedString("gallery.error.connectionFailed", comment: "") : msg
        case .notFound(let name):
            return String(format: NSLocalizedString("Asset nicht gefunden", comment: ""), name)
        case .deleteFailed(let msg):
            return msg
        case .loadFailed(let msg):
            return msg
        }
    }
}
