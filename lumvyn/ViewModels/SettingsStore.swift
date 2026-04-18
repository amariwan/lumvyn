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

    private var reconnectTask: Task<Void, Never>? = nil

    private let defaults = UserDefaults.standard
    private let smbClient: SMBClientProtocol

    var browserClient: any SMBClientProtocol { smbClient }
    private var cancellables = Set<AnyCancellable>()
    private var notificationTokens: [NSObjectProtocol] = []

    init(smbClient: SMBClientProtocol? = nil) {
        self.smbClient = smbClient ?? SMBClient()
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
        reconnectTask?.cancel()
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
                self?.requestReconnect()
            }
            .store(in: &cancellables)

        requestReconnect(initialDelay: .milliseconds(200))
    }

    private struct ConnectionKey: Equatable {
        let host: String
        let share: String
        let user: String
        let password: String
    }

    @MainActor
    private func requestReconnect(initialDelay: DispatchTimeInterval = .milliseconds(0)) {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            if case .milliseconds(let ms) = initialDelay, ms > 0 {
                try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            }
            if Task.isCancelled { return }
            await self?.autoReconnectIfNeeded()
        }
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

        reconnectTask?.cancel()
        reconnectTask = nil

        isTestingConnection = true
        defer { isTestingConnection = false }

        let status = await smbClient.connectionStatus(host: host, sharePath: sharePath, credentials: credentials)
        connectionStatus = status
        switch status {
        case .ready, .authenticated:
            do {
                try await smbClient.probeWrite(host: host, sharePath: sharePath, credentials: credentials ?? SMBCredentials(username: "", password: ""))
                connectionError = nil
                lastConnectionSucceeded = true
            } catch {
                connectionError = (error as NSError).localizedDescription
                lastConnectionSucceeded = false
            }
        default:
            connectionError = status.message ?? NSLocalizedString("SMB-Konfiguration fehlt.", comment: "missing smb config")
            lastConnectionSucceeded = false
        }
    }

    private func loadSettings() {
        let loadedHost = defaults.string(forKey: Keys.host)?.trimmed ?? ""
        host = loadedHost.isEmpty ? Self.defaultHost : loadedHost

        let loadedSharePath = defaults.string(forKey: Keys.sharePath)?.trimmed ?? ""
        sharePath = loadedSharePath.isEmpty ? Self.defaultSharePath : loadedSharePath

        username = defaults.string(forKey: Keys.username) ?? ""
        autoUploadEnabled = defaults.bool(forKey: Keys.autoUpload, defaultValue: true)
        backgroundUploadEnabled = defaults.bool(forKey: Keys.backgroundUpload, defaultValue: true)
        wifiOnlyUpload = defaults.bool(forKey: Keys.wifiOnly, defaultValue: false)
        allowCellularUpload = defaults.bool(forKey: Keys.allowCellular, defaultValue: false)
        uploadSchedule = defaults.enum(forKey: Keys.uploadSchedule, defaultValue: .immediate)
        mediaTypeFilter = defaults.enum(forKey: Keys.mediaTypeFilter, defaultValue: .all)
        dateRangeType = defaults.enum(forKey: Keys.dateRangeType, defaultValue: .allTime)
        customDateRangeStart = defaults.object(forKey: Keys.dateRangeStart) as? Date
        customDateRangeEnd = defaults.object(forKey: Keys.dateRangeEnd) as? Date
        albumFilterEnabled = defaults.bool(forKey: Keys.albumFilterEnabled, defaultValue: false)
        selectedAlbums = defaults.stringArray(forKey: Keys.selectedAlbums) ?? []
        conflictResolution = defaults.enum(forKey: Keys.conflictResolution, defaultValue: .rename)
        encryptionEnabled = defaults.bool(forKey: Keys.encryptionEnabled, defaultValue: false)
        maxConcurrentUploads = defaults.object(forKey: Keys.maxConcurrentUploads) as? Int ?? 2
        deduplicationEnabled = defaults.bool(forKey: Keys.deduplication, defaultValue: true)
        syncMode = defaults.enum(forKey: Keys.syncMode, defaultValue: .backup)
        let storedTemplate = defaults.string(forKey: Keys.folderTemplate)?.trimmed ?? ""
        folderTemplate = storedTemplate.isEmpty ? FolderTemplateResolver.defaultTemplate : storedTemplate
        if let language = defaults.string(forKey: Keys.language), language != "system" {
            selectedLanguage = language
        } else {
            selectedLanguage = nil
        }

        savedPasswordCache = KeychainStorage.string(forKey: Keys.password)
        password = ""

        savedEncryptionPasswordCache = KeychainStorage.string(forKey: Keys.encryptionPassword)
        encryptionPassword = ""
        secureValuesLoaded = true
    }

    func saveSettings() {
        defaults.set(host, forKey: Keys.host)
        defaults.set(sharePath, forKey: Keys.sharePath)
        defaults.set(username, forKey: Keys.username)
        defaults.set(autoUploadEnabled, forKey: Keys.autoUpload)
        defaults.set(backgroundUploadEnabled, forKey: Keys.backgroundUpload)
        defaults.set(wifiOnlyUpload, forKey: Keys.wifiOnly)
        defaults.set(allowCellularUpload, forKey: Keys.allowCellular)
        defaults.set(uploadSchedule.rawValue, forKey: Keys.uploadSchedule)
        defaults.set(mediaTypeFilter.rawValue, forKey: Keys.mediaTypeFilter)
        defaults.set(dateRangeType.rawValue, forKey: Keys.dateRangeType)
        defaults.set(customDateRangeStart, forKey: Keys.dateRangeStart)
        defaults.set(customDateRangeEnd, forKey: Keys.dateRangeEnd)
        defaults.set(albumFilterEnabled, forKey: Keys.albumFilterEnabled)
        defaults.set(selectedAlbums, forKey: Keys.selectedAlbums)
        defaults.set(conflictResolution.rawValue, forKey: Keys.conflictResolution)
        defaults.set(encryptionEnabled, forKey: Keys.encryptionEnabled)
        defaults.set(maxConcurrentUploads, forKey: Keys.maxConcurrentUploads)
        defaults.set(deduplicationEnabled, forKey: Keys.deduplication)
        defaults.set(syncMode.rawValue, forKey: Keys.syncMode)
        defaults.set(folderTemplate, forKey: Keys.folderTemplate)

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
            defaults.set(language, forKey: Keys.language)
        } else {
            defaults.removeObject(forKey: Keys.language)
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
    private func autoReconnectIfNeeded() async {
        if Task.isCancelled { return }

        guard config.isValid, credentials != nil else {
            connectionStatus = .notConfigured
            lastConnectionSucceeded = false
            return
        }

        await performReconnect()
    }

    @MainActor
    private func performReconnect(maxAttempts: Int = 3) async {
        if isTestingConnection { return }
        if Task.isCancelled { return }

        guard config.isValid, let creds = credentials else {
            connectionStatus = .notConfigured
            lastConnectionSucceeded = false
            return
        }

        connectionStatus = .connecting
        lastConnectionSucceeded = false

        var lastStatus: SMBConnectionStatus = .unknown

        for attempt in 1...maxAttempts {
            if Task.isCancelled { return }

            let status = await smbClient.connectionStatus(host: host, sharePath: sharePath, credentials: creds)
            if Task.isCancelled { return }

            connectionStatus = status
            lastStatus = status

            switch status {
            case .ready, .authenticated:
                do {
                    try await smbClient.probeWrite(host: host, sharePath: sharePath, credentials: creds)
                    if Task.isCancelled { return }
                    connectionStatus = .authenticated
                    connectionError = nil
                    lastConnectionSucceeded = true
                    return
                } catch {
                    if Task.isCancelled { return }
                    connectionError = (error as NSError).localizedDescription
                    lastConnectionSucceeded = false
                    connectionStatus = .failed(connectionError ?? "")
                }
            default:
                lastConnectionSucceeded = false
            }

            if attempt < maxAttempts {
                let maxBackoffSeconds = UInt64.max / 1_000_000_000
                let maxBackoffExponent = (UInt64.bitWidth - 1) - maxBackoffSeconds.leadingZeroBitCount
                let exponent = min(attempt - 1, maxBackoffExponent)
                let backoffSeconds = UInt64(1) << exponent
                let backoffNanoseconds = backoffSeconds * 1_000_000_000
                try? await Task.sleep(nanoseconds: backoffNanoseconds)
                if Task.isCancelled { return }
            }
        }

        connectionStatus = lastStatus
    }

    @MainActor
    func reconnectOnForeground() {
        requestReconnect()
    }

    func clearCredentials() {
        reconnectTask?.cancel()
        reconnectTask = nil
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
            if let value = value, !value.isEmpty {
                try KeychainStorage.save(value, forKey: key)
            } else {
                try KeychainStorage.deleteValue(forKey: key)
            }

            if key == Keys.password {
                savedPasswordCache = KeychainStorage.string(forKey: key)
            } else if key == Keys.encryptionPassword {
                savedEncryptionPasswordCache = KeychainStorage.string(forKey: key)
            }
        } catch {
            NSLog("Keychain error for %{public}@ - %{public}@", key, String(describing: error))
        }
    }
}

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        object(forKey: key) == nil ? defaultValue : bool(forKey: key)
    }

    func `enum`<T>(forKey key: String, defaultValue: T) -> T where T: RawRepresentable, T.RawValue == String {
        if let rawValue = string(forKey: key), let value = T(rawValue: rawValue) {
            return value
        }
        return defaultValue
    }
}
