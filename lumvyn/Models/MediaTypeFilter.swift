import Foundation
import Photos

enum MediaTypeFilter: String, Codable, CaseIterable, Equatable, Identifiable {
    case all
    case photos
    case videos
    case livePhotos
    case screenshots
    case panoramas
    case bursts
    case slowMotion
    case timeLapse
    case hdr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return NSLocalizedString("Alle Medien", comment: "Media filter: all media")
        case .photos: return NSLocalizedString("Fotos", comment: "Media filter: photos")
        case .videos: return NSLocalizedString("Videos", comment: "Media filter: videos")
        case .livePhotos: return NSLocalizedString("Live-Fotos", comment: "Media filter: live photos")
        case .screenshots: return NSLocalizedString("Screenshots", comment: "Media filter: screenshots")
        case .panoramas: return NSLocalizedString("Panoramen", comment: "Media filter: panoramas")
        case .bursts: return NSLocalizedString("Serienaufnahmen", comment: "Media filter: bursts")
        case .slowMotion: return NSLocalizedString("Slow-Motion", comment: "Media filter: slow motion")
        case .timeLapse: return NSLocalizedString("Time-Lapse", comment: "Media filter: time lapse")
        case .hdr: return NSLocalizedString("HDR", comment: "Media filter: HDR")
        }
    }

    var predicate: NSPredicate? {
        switch self {
        case .all:
            return nil
        case .photos:
            return NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        case .videos:
            return NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        case .livePhotos:
            return NSPredicate(format: "mediaSubtypes & %d != 0", PHAssetMediaSubtype.photoLive.rawValue)
        case .screenshots:
            return NSPredicate(format: "mediaSubtypes & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        case .panoramas:
            return NSPredicate(format: "mediaSubtypes & %d != 0", PHAssetMediaSubtype.photoPanorama.rawValue)
        case .bursts:
            return nil
        case .slowMotion:
            return NSPredicate(format: "mediaSubtypes & %d != 0", PHAssetMediaSubtype.videoHighFrameRate.rawValue)
        case .timeLapse:
            return NSPredicate(format: "mediaSubtypes & %d != 0", PHAssetMediaSubtype.videoTimelapse.rawValue)
        case .hdr:
            return NSPredicate(format: "mediaSubtypes & %d != 0", PHAssetMediaSubtype.photoHDR.rawValue)
        }
    }

    func matches(asset: PHAsset) -> Bool {
        switch self {
        case .all:
            return true
        case .photos:
            return asset.mediaType == .image
        case .videos:
            return asset.mediaType == .video
        case .livePhotos:
            return asset.mediaSubtypes.contains(.photoLive)
        case .screenshots:
            return asset.mediaSubtypes.contains(.photoScreenshot)
        case .panoramas:
            return asset.mediaSubtypes.contains(.photoPanorama)
        case .bursts:
            return asset.burstIdentifier != nil
        case .slowMotion:
            return asset.mediaSubtypes.contains(.videoHighFrameRate)
        case .timeLapse:
            return asset.mediaSubtypes.contains(.videoTimelapse)
        case .hdr:
            return asset.mediaSubtypes.contains(.photoHDR)
        }
    }
}
