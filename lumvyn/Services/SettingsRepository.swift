import Foundation

protocol SettingsRepositoryProtocol: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func bool(forKey key: String, defaultValue: Bool) -> Bool
    func set(_ value: Bool, forKey key: String)
    func enumValue<T: RawRepresentable>(forKey key: String, defaultValue: T) -> T where T.RawValue == String
    func setEnum<T: RawRepresentable>(_ value: T, forKey key: String) where T.RawValue == String
    func object(forKey key: String) -> Any?
    func setObject(_ value: Any?, forKey key: String)
    func stringArray(forKey key: String) -> [String]?

    // Keychain helpers
    func secureString(forKey key: String) -> String?
    func saveSecure(_ value: String?, forKey key: String) throws
    func deleteSecure(forKey key: String) throws
}

final class UserDefaultsSettingsRepository: SettingsRepositoryProtocol {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        if let v = value {
            defaults.set(v, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func enumValue<T>(forKey key: String, defaultValue: T) -> T where T: RawRepresentable, T.RawValue == String {
        if let raw = defaults.string(forKey: key), let value = T(rawValue: raw) {
            return value
        }
        return defaultValue
    }

    func setEnum<T>(_ value: T, forKey key: String) where T: RawRepresentable, T.RawValue == String {
        defaults.set(value.rawValue, forKey: key)
    }

    func object(forKey key: String) -> Any? {
        return defaults.object(forKey: key)
    }

    func setObject(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func stringArray(forKey key: String) -> [String]? {
        defaults.stringArray(forKey: key)
    }

    // Keychain helpers delegate to existing KeychainStorage utility
    func secureString(forKey key: String) -> String? {
        KeychainStorage.string(forKey: key)
    }

    func saveSecure(_ value: String?, forKey key: String) throws {
        if let value = value, !value.isEmpty {
            try KeychainStorage.save(value, forKey: key)
        } else {
            try KeychainStorage.deleteValue(forKey: key)
        }
    }

    func deleteSecure(forKey key: String) throws {
        try KeychainStorage.deleteValue(forKey: key)
    }
}
