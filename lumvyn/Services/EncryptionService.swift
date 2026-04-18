import Foundation
import CryptoKit
import CommonCrypto

public enum EncryptionServiceError: LocalizedError {
    case invalidKey
    case encryptionFailed
    case decryptionFailed

    public var errorDescription: String? {
        switch self {
            case .invalidKey: return NSLocalizedString("Ungültiger Verschlüsselungsschlüssel.", comment: "Invalid encryption key")
            case .encryptionFailed: return NSLocalizedString("Verschlüsselung fehlgeschlagen.", comment: "Encryption failed")
            case .decryptionFailed: return NSLocalizedString("Entschlüsselung fehlgeschlagen.", comment: "Decryption failed")
        }
    }
}

public struct EncryptionService: Sendable {
    public let key: SymmetricKey

    public init(password: String, salt: Data = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])) {
        self.key = Self.makeKey(password: password, salt: salt)
    }

    public init(key: SymmetricKey) {
        self.key = key
    }

    public static func makeKey(password: String, salt: Data) -> SymmetricKey {
        var derivedKey = [UInt8](repeating: 0, count: 32)

        let status = password.withCString { pwdPtr in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwdPtr,
                    password.utf8.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    100_000,
                    &derivedKey,
                    derivedKey.count
                )
            }
        }

        guard status == kCCSuccess else {
            let fallbackHash = SHA256.hash(data: Data(password.utf8))
            return SymmetricKey(data: Data(fallbackHash))
        }

        return SymmetricKey(data: derivedKey)
    }

    public func encrypt(_ data: Data) throws -> Data {
        guard let combined = try? AES.GCM.seal(data, using: key).combined else {
            throw EncryptionServiceError.encryptionFailed
        }
        return combined
    }

    public func decrypt(_ data: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw EncryptionServiceError.decryptionFailed
        }
    }
}
