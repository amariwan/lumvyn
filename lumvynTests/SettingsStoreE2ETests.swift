import XCTest
@testable import lumvyn

/// Lightweight actor-based test SMB client that records calls and simulates responses.
actor RecordingSMBClient: SMBClientProtocol {
    var connectionStatusToReturn: SMBConnectionStatus = .ready
    private(set) var probeWriteCalled: Bool = false

    func setConnectionStatus(_ s: SMBConnectionStatus) async {
        connectionStatusToReturn = s
    }

    func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {
        // no-op for tests
    }

    func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus {
        return connectionStatusToReturn
    }

    func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {
        probeWriteCalled = true
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
        progress(1.0)
        return remotePath
    }

}

final class SettingsStoreE2ETests: XCTestCase {

    func testTestConnectionSucceedsWithReadyStatus() async {
        let client = RecordingSMBClient()
        let store = await MainActor.run { SettingsStore(smbClient: client) }

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

        let probeCalled = await client.probeWriteCalled
        XCTAssertTrue(probeCalled)
    }

    func testTestConnectionReportsFailureWhenStatusIsFailed() async {
        let client = RecordingSMBClient()
        await client.setConnectionStatus(.failed("boom"))
        let store = await MainActor.run { SettingsStore(smbClient: client) }

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
        }
    }
}
