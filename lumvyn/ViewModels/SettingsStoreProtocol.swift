
import Foundation
import Combine

protocol SettingsStoreProtocol: AnyObject, ObservableObject {
    var host: String { get set }
    var sharePath: String { get set }

    var autoUploadEnabled: Bool { get set }
    var uploadSchedule: UploadSchedule { get set }
    var syncMode: SyncMode { get set }
    var deduplicationEnabled: Bool { get set }
    var isConfigured: Bool { get }
    var config: SMBServerConfig { get }
    var credentials: SMBCredentials? { get }

    // Encryption key (derived from secure storage / entered password)
    var encryptionKey: String? { get }

    // Folder template used to resolve remote directories
    var folderTemplate: String { get set }

    // Expose a browser-capable SMB client for directory listings and downloads
    var browserClient: any SMBClientProtocol { get }

    // Publishers for reactive consumers
    var autoUploadEnabledPublisher: AnyPublisher<Bool, Never> { get }
    var uploadSchedulePublisher: AnyPublisher<UploadSchedule, Never> { get }
}
