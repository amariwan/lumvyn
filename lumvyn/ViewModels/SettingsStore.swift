import Foundation
import Combine

#if os(iOS)
import UIKit
#endif

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let host = "SMBHost"
        static let sharePath = "SMBSharePath"
        static let autoUpload = "SMBAutoUploadEnabled"
        static let backgroundUpload = "SMBBackgroundUploadEnabled"
        static let username = "SMBUsername"
        static let password = "SMBPassword"
        static let wifiOnly = "SMBWiFiOnly"
        static let allowCellular = "SMBAllowCellular"
        static let uploadSchedule = "SMBUploadSchedule"
        static let mediaTypeFilter = "SMBMediaTypeFilter"
        static let dateRangeType = "SMBDateRangeType"
        static let dateRangeStart = "SMBDateRangeStart"
        static let dateRangeEnd = "SMBDateRangeEnd"
        static let albumFilterEnabled = "SMBAlbumFilterEnabled"
        static let selectedAlbums = "SMBSelectedAlbums"
        static let conflictResolution = "SMBConflictResolution"
        static let encryptionEnabled = "SMBEncryptionEnabled"
        static let maxConcurrentUploads = "SMBMaxConcurrentUploads"
        static let encryptionPassword = "SMBEncryptionPassword"
        static let language = "AppLanguage"
        static let deduplication = "SMBDeduplicationEnabled"
        static let syncMode = "SMBSyncMode"
        static let folderTemplate = "SMBFolderTemplate"
    }

    private static let defaultHost = "192.168.178.2"
    private static let defaultSharePath = "/photos"

    @Published var host: String = defaultHost
    @Published var sharePath: String = defaultSharePath
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var autoUploadEnabled: Bool = true
    @Published var backgroundUploadEnabled: Bool = true
    @Published var wifiOnlyUpload: Bool = false
    @Published var allowCellularUpload: Bool = false
    @Published var uploadSchedule: UploadSchedule = .immediate
    @Published var mediaTypeFilter: MediaTypeFilter = .all
    @Published var dateRangeType: DateRangeType = .allTime
    @Published var customDateRangeStart: Date? = nil
    @Published var customDateRangeEnd: Date? = nil
    @Published var albumFilterEnabled: Bool = false
    @Published var selectedAlbums: [String] = []
    @Published var conflictResolution: ConflictResolution = .rename
    @Published var encryptionEnabled: Bool = false
    @Published var maxConcurrentUploads: Int = 2
    @Published var encryptionPassword: String = ""
    @Published var deduplicationEnabled: Bool = true
    @Published var syncMode: SyncMode = .backup
    @Published var folderTemplate: String = FolderTemplateResolver.defaultTemplate
    @Published var selectedLanguage: String? = nil

    @Published var connectionError: String? = nil
    @Published var lastConnectionSucceeded: Bool = false
    @Published var connectionStatus: SMBConnectionStatus = .unknown
    @Published var isTestingConnection: Bool = false

    private var savedPasswordCache: String? = nil
    private var savedEncryptionPasswordCache: String? = nil
    private var secureValuesLoaded: Bool = false
    private var securePasswordDirty: Bool = false
    private var secureEncryptionDirty: Bool = false

    private let repository: SettingsRepositoryProtocol
    private let smbClient: SMBClientProtocol
    private let connectionService: ConnectionServiceProtocol

    var browserClient: any SMBClientProtocol { smbClient }
    private var cancellables = Set<AnyCancellable>()
    private var notificationTokens: [NSObjectProtocol] = []

    init(smbClient: SMBClientProtocol? = nil, repository: SettingsRepositoryProtocol? = nil, connectionService: ConnectionServiceProtocol? = nil) {
        self.smbClient = smbClient ?? SMBClient()
        self.repository = repository ?? UserDefaultsSettingsRepository()
        self.connectionService = connectionService ?? ConnectionService(smbClient: self.smbClient)

        // Subscribe to connection service updates and mirror into this store's published properties
        self.connectionService.connectionStatusPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] status in self?.connectionStatus = status }
            .store(in: &cancellables)

        self.connectionService.connectionErrorPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] err in self?.connectionError = err }
            .store(in: &cancellables)

        self.connectionService.lastConnectionSucceededPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] ok in self?.lastConnectionSucceeded = ok }
            .store(in: &cancellables)

        self.connectionService.isTestingConnectionPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] testing in self?.isTestingConnection = testing }
            .store(in: &cancellables)

        loadSettings()
        setupAutoSave()
        #if os(iOS)
        let center = NotificationCenter.default
        let resign = center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.saveSettings()
        }
        let background = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.saveSettings()
        }
        notificationTokens.append(resign)
        notificationTokens.append(background)
        #endif
    }

    deinit {
        Task { @MainActor in
            connectionService.cancelReconnect()
        }
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func setupAutoSave() {
        let publishers: [AnyPublisher<Void, Never>] = [
            makeSavePublisher($host),
            makeSavePublisher($sharePath),
            makeSavePublisher($username),
            makeSavePublisher($password),
            makeSavePublisher($autoUploadEnabled),
            makeSavePublisher($backgroundUploadEnabled),
            makeSavePublisher($wifiOnlyUpload),
            makeSavePublisher($allowCellularUpload),
            makeSavePublisher($uploadSchedule),
            makeSavePublisher($mediaTypeFilter),
            makeSavePublisher($dateRangeType),
            makeSavePublisher($customDateRangeStart),
            makeSavePublisher($customDateRangeEnd),
            makeSavePublisher($albumFilterEnabled),
            makeSavePublisher($selectedAlbums),
            makeSavePublisher($conflictResolution),
            makeSavePublisher($encryptionEnabled),
            makeSavePublisher($maxConcurrentUploads),
            makeSavePublisher($encryptionPassword),
            makeSavePublisher($deduplicationEnabled),
            makeSavePublisher($syncMode),
            makeSavePublisher($folderTemplate),
            makeSavePublisher($selectedLanguage)
        ]

        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.autoSaveSettings() }
            }
            .store(in: &cancellables)

        $password
            .dropFirst()
            .sink { [weak self] new in
                guard let self = self else { return }
                if !self.secureValuesLoaded { return }
                if new.isEmpty { return }
                self.securePasswordDirty = (new != self.savedPasswordCache)
            }
            .store(in: &cancellables)

        $encryptionPassword
            .dropFirst()
            .sink { [weak self] new in
                guard let self = self else { return }
                if !self.secureValuesLoaded { return }
                if new.isEmpty { return }
                self.secureEncryptionDirty = (new != self.savedEncryptionPasswordCache)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4($host, $sharePath, $username, $password)
            .map { [weak self] host, share, user, pw -> ConnectionKey in
                let effectivePw = pw.isEmpty ? (self?.savedPasswordCache ?? "") : pw
                return ConnectionKey(host: host.trimmed, share: share.trimmed, user: user.trimmed, password: effectivePw)
            }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.connectionService.requestReconnect(host: self.host, sharePath: self.sharePath, credentials: self.credentials, initialDelay: .milliseconds(200))
            }
            .store(in: &cancellables)

        connectionService.requestReconnect(host: host, sharePath: sharePath, credentials: credentials, initialDelay: .milliseconds(200))
    }

    private struct ConnectionKey: Equatable {
        let host: String
        let share: String
        let user: String
        let password: String
    }



    private func makeSavePublisher<P>(_ publisher: Published<P>.Publisher) -> AnyPublisher<Void, Never> {
        publisher.map { _ in () }.eraseToAnyPublisher()
    }

    @MainActor
    private func autoSaveSettings() async {
        saveSettings()
    }

    @MainActor
    func testConnection() async {
        guard !host.trimmed.isEmpty, !sharePath.trimmed.isEmpty else {
            connectionError = NSLocalizedString("SMB-Konfiguration fehlt.", comment: "missing smb config")
            lastConnectionSucceeded = false
            return
        }

        if !trimmedUsername.isEmpty && credentials == nil {
            connectionError = NSLocalizedString("Benutzername oder Passwort fehlt.", comment: "missing smb credentials")
            lastConnectionSucceeded = false
            return
        }

        connectionService.cancelReconnect()
        await connectionService.testConnection(host: host, sharePath: sharePath, credentials: credentials)
    }

    private func loadSettings() {
        let loadedHost = repository.string(forKey: Keys.host)?.trimmed ?? ""
        host = loadedHost.isEmpty ? Self.defaultHost : loadedHost

        let loadedSharePath = repository.string(forKey: Keys.sharePath)?.trimmed ?? ""
        sharePath = loadedSharePath.isEmpty ? Self.defaultSharePath : loadedSharePath

        username = repository.string(forKey: Keys.username) ?? ""
        autoUploadEnabled = repository.bool(forKey: Keys.autoUpload, defaultValue: true)
        backgroundUploadEnabled = repository.bool(forKey: Keys.backgroundUpload, defaultValue: true)
        wifiOnlyUpload = repository.bool(forKey: Keys.wifiOnly, defaultValue: false)
        allowCellularUpload = repository.bool(forKey: Keys.allowCellular, defaultValue: false)
        uploadSchedule = repository.enumValue(forKey: Keys.uploadSchedule, defaultValue: .immediate)
        mediaTypeFilter = repository.enumValue(forKey: Keys.mediaTypeFilter, defaultValue: .all)
        dateRangeType = repository.enumValue(forKey: Keys.dateRangeType, defaultValue: .allTime)
        customDateRangeStart = repository.object(forKey: Keys.dateRangeStart) as? Date
        customDateRangeEnd = repository.object(forKey: Keys.dateRangeEnd) as? Date
        albumFilterEnabled = repository.bool(forKey: Keys.albumFilterEnabled, defaultValue: false)
        selectedAlbums = repository.stringArray(forKey: Keys.selectedAlbums) ?? []
        conflictResolution = repository.enumValue(forKey: Keys.conflictResolution, defaultValue: .rename)
        encryptionEnabled = repository.bool(forKey: Keys.encryptionEnabled, defaultValue: false)
        maxConcurrentUploads = repository.object(forKey: Keys.maxConcurrentUploads) as? Int ?? 2
        deduplicationEnabled = repository.bool(forKey: Keys.deduplication, defaultValue: true)
        syncMode = repository.enumValue(forKey: Keys.syncMode, defaultValue: .backup)
        let storedTemplate = repository.string(forKey: Keys.folderTemplate)?.trimmed ?? ""
        folderTemplate = storedTemplate.isEmpty ? FolderTemplateResolver.defaultTemplate : storedTemplate
        if let language = repository.string(forKey: Keys.language), language != "system" {
            selectedLanguage = language
        } else {
            selectedLanguage = nil
        }

        savedPasswordCache = repository.secureString(forKey: Keys.password)
        password = ""

        savedEncryptionPasswordCache = repository.secureString(forKey: Keys.encryptionPassword)
        encryptionPassword = ""
        secureValuesLoaded = true
    }

    func saveSettings() {
        repository.set(host, forKey: Keys.host)
        repository.set(sharePath, forKey: Keys.sharePath)
        repository.set(username, forKey: Keys.username)
        repository.set(autoUploadEnabled, forKey: Keys.autoUpload)
        repository.set(backgroundUploadEnabled, forKey: Keys.backgroundUpload)
        repository.set(wifiOnlyUpload, forKey: Keys.wifiOnly)
        repository.set(allowCellularUpload, forKey: Keys.allowCellular)
        repository.setEnum(uploadSchedule, forKey: Keys.uploadSchedule)
        repository.setEnum(mediaTypeFilter, forKey: Keys.mediaTypeFilter)
        repository.setEnum(dateRangeType, forKey: Keys.dateRangeType)
        repository.setObject(customDateRangeStart, forKey: Keys.dateRangeStart)
        repository.setObject(customDateRangeEnd, forKey: Keys.dateRangeEnd)
        repository.set(albumFilterEnabled, forKey: Keys.albumFilterEnabled)
        repository.setObject(selectedAlbums, forKey: Keys.selectedAlbums)
        repository.setEnum(conflictResolution, forKey: Keys.conflictResolution)
        repository.set(encryptionEnabled, forKey: Keys.encryptionEnabled)
        repository.setObject(maxConcurrentUploads, forKey: Keys.maxConcurrentUploads)
        repository.set(deduplicationEnabled, forKey: Keys.deduplication)
        repository.setEnum(syncMode, forKey: Keys.syncMode)
        repository.set(folderTemplate, forKey: Keys.folderTemplate)

        if securePasswordDirty {
            if !password.isEmpty {
                setSecureValue(password, forKey: Keys.password)
            }
            securePasswordDirty = false
        }

        if secureEncryptionDirty {
            if !encryptionPassword.isEmpty {
                setSecureValue(encryptionPassword, forKey: Keys.encryptionPassword)
            }
            secureEncryptionDirty = false
        }

        if let language = selectedLanguage {
            repository.set(language, forKey: Keys.language)
        } else {
            repository.set(nil, forKey: Keys.language)
        }
    }

    var savedPassword: String? {
        savedPasswordCache
    }

    var hasSavedPassword: Bool {
        savedPasswordCache != nil
    }

    var credentials: SMBCredentials? {
        guard !trimmedUsername.isEmpty else { return nil }
        let passwordToUse = password.isEmpty ? savedPassword : password
        guard let password = passwordToUse, !password.isEmpty else { return nil }
        return SMBCredentials(username: username, password: password)
    }

    var hasIncompleteCredentials: Bool {
        !trimmedUsername.isEmpty && credentials == nil
    }

    var encryptionKey: String? {
        guard !encryptionPassword.isEmpty else { return savedEncryptionPasswordCache }
        return encryptionPassword
    }

    var config: SMBServerConfig {
        SMBServerConfig(
            host: host,
            sharePath: sharePath,
            autoUploadEnabled: autoUploadEnabled,
            backgroundUploadEnabled: backgroundUploadEnabled,
            wifiOnlyUpload: wifiOnlyUpload,
            allowCellularUpload: allowCellularUpload,
            uploadSchedule: uploadSchedule,
            mediaTypeFilter: mediaTypeFilter,
            dateRangeOption: DateRangeOption(type: dateRangeType, startDate: customDateRangeStart, endDate: customDateRangeEnd),
            albumFilterEnabled: albumFilterEnabled,
            selectedAlbums: selectedAlbums,
            conflictResolution: conflictResolution,
            encryptionEnabled: encryptionEnabled,
            maxConcurrentUploads: maxConcurrentUploads,
            syncMode: syncMode,
            folderTemplate: folderTemplate
        )
    }

    var isConfigured: Bool {
        config.isValid && credentials != nil
    }



    @MainActor
    func reconnectOnForeground() {
        connectionService.requestReconnect(host: host, sharePath: sharePath, credentials: credentials, initialDelay: .milliseconds(200))
    }

    func clearCredentials() {
        connectionService.cancelReconnect()
        setSecureValue(nil, forKey: Keys.password)
        securePasswordDirty = false
        password = ""
        connectionStatus = .notConfigured
        lastConnectionSucceeded = false
    }

    func clearEncryptionPassword() {
        setSecureValue(nil, forKey: Keys.encryptionPassword)
        secureEncryptionDirty = false
        encryptionPassword = ""
    }

    private var trimmedUsername: String {
        username.trimmed
    }

    private func setSecureValue(_ value: String?, forKey key: String) {
        do {
            try repository.saveSecure(value, forKey: key)

            if key == Keys.password {
                savedPasswordCache = repository.secureString(forKey: key)
            } else if key == Keys.encryptionPassword {
                savedEncryptionPasswordCache = repository.secureString(forKey: key)
            }
        } catch {
            NSLog("Keychain error for %{public}@ - %{public}@", key, String(describing: error))
        }
    }
}

extension SettingsStore: SettingsStoreProtocol {
    var autoUploadEnabledPublisher: AnyPublisher<Bool, Never> {
        $autoUploadEnabled.eraseToAnyPublisher()
    }

    var uploadSchedulePublisher: AnyPublisher<UploadSchedule, Never> {
        $uploadSchedule.eraseToAnyPublisher()
    }
}
