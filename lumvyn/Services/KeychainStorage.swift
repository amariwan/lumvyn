import Foundation
import Security

public enum KeychainError: LocalizedError {
    case unhandledError(status: OSStatus)
}

public enum KeychainStorage {
    private static let service: String = Bundle.main.bundleIdentifier ?? "lumvyn"

    private static func baseQuery(forKey key: String, includeService: Bool = true) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        if includeService {
            query[kSecAttrService] = service
        }
        return query
    }

    public static func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(forKey: key)

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            let newItem = query.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }

            cleanupLegacyItem(forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }

    public static func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(decoding: data, as: UTF8.self)
        }

        return performLegacyMigration(forKey: key)
    }

    public static func deleteValue(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        cleanupLegacyItem(forKey: key)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    private static func cleanupLegacyItem(forKey key: String) {
        let legacyQuery = baseQuery(forKey: key, includeService: false)
        SecItemDelete(legacyQuery as CFDictionary)
    }

    private static func performLegacyMigration(forKey key: String) -> String? {
        var legacyQuery = baseQuery(forKey: key, includeService: false)
        legacyQuery[kSecReturnData] = true
        legacyQuery[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            let value = String(decoding: data, as: UTF8.self)
            try? save(value, forKey: key)
            return value
        }

        return nil
    }
}
