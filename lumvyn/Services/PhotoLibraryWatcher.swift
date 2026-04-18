import Foundation
import Combine
import Photos

protocol PhotoLibraryWatcherDelegate: AnyObject {
    func photoLibraryWatcher(_ watcher: PhotoLibraryWatcher, didDetect newAssets: [PHAsset])
}

@MainActor
final class PhotoLibraryWatcher: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    weak var delegate: PhotoLibraryWatcherDelegate?
    private let userDefaultsKey = "PhotoLibraryWatcherLastScan"
    private var lastScanDate: Date? {
        get { UserDefaults.standard.object(forKey: userDefaultsKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }

    init(delegate: PhotoLibraryWatcherDelegate? = nil) {
        self.delegate = delegate
        super.init()
    }

    func start() {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) != .denied else {
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { await self?.handleAuthorization(status) }
        }
    }

    @MainActor
    private func handleAuthorization(_ status: PHAuthorizationStatus) async {
        switch status {
        case .authorized, .limited:
            PHPhotoLibrary.shared().register(self)
            await scanLibrary()
        default:
            break
        }
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { await self.scanLibrary() }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    @MainActor
    func scanLibrary() async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
                PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else {
            return
        }

        let assets = fetchRecentAssets()

        Task.detached(priority: .utility) {
            let cachingManager = PHCachingImageManager()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            cachingManager.startCachingImages(for: assets, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: options)
        }

        delegate?.photoLibraryWatcher(self, didDetect: assets)
        lastScanDate = Date()
    }

    private func fetchRecentAssets() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        if let lastScanDate {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastScanDate as NSDate)
        } else {
            fetchOptions.fetchLimit = 200
        }

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var assets = [PHAsset]()

        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }
}
