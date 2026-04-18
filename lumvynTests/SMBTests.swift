import XCTest
@testable import lumvyn

final class MockSMBClient: SMBClientProtocol {
    private let shouldSucceed: Bool

    init(shouldSucceed: Bool) {
        self.shouldSucceed = shouldSucceed
    }

    func upload(
        fileURL: URL,
        to remotePath: String,
        host: String,
        sharePath: String,
        credentials: SMBCredentials,
        conflictResolution: ConflictResolution,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> String {
        if shouldSucceed {
            progress(1.0)
            return remotePath
        } else {
            throw NSError(domain: "MockSMBClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock upload failed"])
        }
    }

    func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {
        if shouldSucceed {
            return
        } else {
            throw NSError(domain: "MockSMBClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
    }

    func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {
        if shouldSucceed {
            return
        } else {
            throw NSError(domain: "MockSMBClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock write failed"])
        }
    }

    func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus {
        if shouldSucceed {
            return .ready
        } else {
            return .failed("Mock failure")
        }
    }
}

final class SMBTests: XCTestCase {
    func testSettingsStoreConnectionSuccess() async {
        let mock = MockSMBClient(shouldSucceed: true)
        let store = await MainActor.run { SettingsStore(smbClient: mock) }

        await MainActor.run {
            store.host = "example.com"
            store.sharePath = "/share"
            store.username = "user"
            store.password = "pass"
        }

        await store.testConnection()

        await MainActor.run {
            XCTAssertTrue(store.lastConnectionSucceeded)
            XCTAssertNil(store.connectionError)
        }
    }

    func testSettingsStoreConnectionFailure() async {
        let mock = MockSMBClient(shouldSucceed: false)
        let store = await MainActor.run { SettingsStore(smbClient: mock) }

        await MainActor.run {
            store.host = "example.com"
            store.sharePath = "/share"
            store.username = "user"
            store.password = "pass"
        }

        await store.testConnection()

        await MainActor.run {
            XCTAssertFalse(store.lastConnectionSucceeded)
            XCTAssertNotNil(store.connectionError)
            XCTAssert(store.connectionError!.contains("Mock failure"))
        }
    }
}
