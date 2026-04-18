import Foundation

enum ConflictResolution: String, Codable, CaseIterable, Equatable, Identifiable {
    case overwrite
    case skip
    case rename

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overwrite: return NSLocalizedString("Überschreiben", comment: "Conflict resolution: overwrite")
        case .skip: return NSLocalizedString("Überspringen", comment: "Conflict resolution: skip")
        case .rename: return NSLocalizedString("Umbenennen", comment: "Conflict resolution: rename")
        }
    }
}
