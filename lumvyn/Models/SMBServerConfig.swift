import Foundation

// MARK: - SyncMode

enum SyncMode: String, Codable, CaseIterable, Equatable, Identifiable {
    /// Upload only. Remote files are never automatically deleted.
    case backup
    /// Strict 1-to-1 mirror. Remote files whose local asset has been deleted are
    /// removed from the server so the remote always reflects the local library.
    case mirror

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backup: return NSLocalizedString("Backup", comment: "Sync mode: backup")
        case .mirror: return NSLocalizedString("Spiegel", comment: "Sync mode: mirror")
        }
    }

    var systemImage: String {
        switch self {
        case .backup: return "arrow.up.to.line"
        case .mirror: return "arrow.triangle.2.circlepath"
        }
    }
}

struct SMBCredentials: Codable, Equatable {
    let username: String
    let password: String
}

enum UploadSchedule: String, Codable, CaseIterable, Equatable, Identifiable {
    case immediate
    case hourly
    case daily
    case weekly
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediate: return NSLocalizedString("Sofort", comment: "Upload schedule: immediate")
        case .hourly: return NSLocalizedString("Stündlich", comment: "Upload schedule: hourly")
        case .daily: return NSLocalizedString("Täglich", comment: "Upload schedule: daily")
        case .weekly: return NSLocalizedString("Wöchentlich", comment: "Upload schedule: weekly")
        case .manual: return NSLocalizedString("Manuell", comment: "Upload schedule: manual")
        }
    }
}

struct SMBServerConfig: Codable, Equatable {
    var host: String = ""
    var sharePath: String = ""
    var autoUploadEnabled: Bool = true
    var backgroundUploadEnabled: Bool = true
    var wifiOnlyUpload: Bool = false
    var allowCellularUpload: Bool = false
    var uploadSchedule: UploadSchedule = .immediate
    var mediaTypeFilter: MediaTypeFilter = .all
    var dateRangeOption: DateRangeOption = DateRangeOption()
    var albumFilterEnabled: Bool = false
    var selectedAlbums: [String] = []
    var conflictResolution: ConflictResolution = .rename
    var encryptionEnabled: Bool = false
    var maxConcurrentUploads: Int = 2
    var syncMode: SyncMode = .backup
    var folderTemplate: String = FolderTemplateResolver.defaultTemplate

    var isValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sharePath.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
