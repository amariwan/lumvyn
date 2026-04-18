import Foundation
import Photos
import CoreLocation

extension PHAsset {
    var primaryFilename: String {
        guard let resource = PHAssetResource.assetResources(for: self).first else {
            return localIdentifier
        }
        let filename = resource.originalFilename
        return filename.isEmpty ? localIdentifier : filename
    }

    var sourceTypeName: String {
        switch sourceType {
        case .typeUserLibrary: return NSLocalizedString("Benutzerbibliothek", comment: "Asset source type: user library")
        case .typeCloudShared: return NSLocalizedString("iCloud Shared", comment: "Asset source type: iCloud shared")
        case .typeiTunesSynced: return NSLocalizedString("iTunes synchronisiert", comment: "Asset source type: iTunes synced")
        default: return NSLocalizedString("Unbekannt", comment: "Asset source type: unknown")
        }
    }

    var subtypeNames: [String] {
        var names = [String]()
        let subtypes: [PHAssetMediaSubtype] = [
            .photoPanorama,
            .photoHDR,
            .photoScreenshot,
            .photoLive,
            .videoHighFrameRate,
            .videoTimelapse,
            .videoStreamed,
            .photoDepthEffect
        ]
        for subtype in subtypes {
            if mediaSubtypes.contains(subtype) {
                switch subtype {
                case .photoPanorama: names.append(NSLocalizedString("Panorama", comment: "Asset subtype: panorama"))
                case .photoHDR: names.append(NSLocalizedString("HDR", comment: "Asset subtype: HDR"))
                case .photoScreenshot: names.append(NSLocalizedString("Screenshot", comment: "Asset subtype: screenshot"))
                case .photoLive: names.append(NSLocalizedString("Live Photo", comment: "Asset subtype: live photo"))
                case .videoHighFrameRate: names.append(NSLocalizedString("Slow-Motion", comment: "Asset subtype: slow motion"))
                case .videoTimelapse: names.append(NSLocalizedString("Time-Lapse", comment: "Asset subtype: time lapse"))
                case .videoStreamed: names.append(NSLocalizedString("Stream", comment: "Asset subtype: streamed video"))
                case .photoDepthEffect: names.append(NSLocalizedString("Tiefeneffekt", comment: "Asset subtype: depth effect"))
                default: break
                }
            }
        }
        if burstIdentifier != nil {
            names.append(NSLocalizedString("Burst", comment: "Asset subtype: burst"))
        }
        return names
    }

    var locationDescription: String? {
        guard let location = location else { return nil }
        return String(format: "%.4f°, %.4f°", location.coordinate.latitude, location.coordinate.longitude)
    }
}
