import XCTest
@testable import lumvyn

final class SettingsStoreTests: XCTestCase {

    final class DummySMBClient: SMBClientProtocol {
        func upload(
            fileURL: URL,
            to remotePath: String,
            host: String,
            sharePath: String,
            credentials: SMBCredentials,
            conflictResolution: ConflictResolution,
            progress: @escaping @Sendable (Double) -> Void
        ) async throws -> String {
            progress(1.0)
            return remotePath
        }

        func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {
            return
        }

        func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus {
            return .ready
        }

        func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {
            return
        }
    }

    func testConfigAndIsConfigured() async {
        let mock = DummySMBClient()
        let store = await MainActor.run { SettingsStore(smbClient: mock) }

        await MainActor.run {
            store.clearCredentials()
        }

        await MainActor.run {
            XCTAssertFalse(store.isConfigured)
            store.host = "example.com"
            store.sharePath = "/share"
            store.username = "user"
            store.password = "pass"
            XCTAssertTrue(store.isConfigured)
            XCTAssertEqual(store.config.host, "example.com")
        }
    }

    func testHasIncompleteCredentials() async {
        let mock = DummySMBClient()
        let store = await MainActor.run { SettingsStore(smbClient: mock) }

        // Ensure no saved credentials interfere with test
        await MainActor.run {
            store.clearCredentials()
        }

        await MainActor.run {
            store.username = "user"
            store.password = ""
            XCTAssertTrue(store.hasIncompleteCredentials)
            store.password = "pass"
            XCTAssertFalse(store.hasIncompleteCredentials)
        }
    }

    func testEncryptionKeyPrefersEnteredPassword() async {
        let mock = DummySMBClient()
        let store = await MainActor.run { SettingsStore(smbClient: mock) }

        await MainActor.run {
            store.encryptionPassword = "secret"
            XCTAssertEqual(store.encryptionKey, "secret")
            store.encryptionPassword = ""
            XCTAssertNil(store.encryptionKey)
        }
    }

}
