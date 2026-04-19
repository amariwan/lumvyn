import XCTest
@testable import lumvyn

final class ConnectionServiceTests: XCTestCase {

    final class MockSMBClient: SMBClientProtocol {
        var statusToReturn: SMBConnectionStatus
        var probeThrows: Bool

        init(status: SMBConnectionStatus = .ready, probeThrows: Bool = false) {
            self.statusToReturn = status
            self.probeThrows = probeThrows
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

        func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {
            // no-op for mock
        }

        func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus {
            return statusToReturn
        }

        func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {
            if probeThrows { throw NSError(domain: "Mock", code: 1, userInfo: nil) }
        }
    }

    func testTestConnectionSucceeds() async {
        let mock = MockSMBClient(status: .ready)
        let service = ConnectionService(smbClient: mock)

        await service.testConnection(host: "host", sharePath: "/photos", credentials: SMBCredentials(username: "u", password: "p"))

        XCTAssertTrue(await MainActor.run { service.lastConnectionSucceeded })
        XCTAssertNil(await MainActor.run { service.connectionError })
    }

    func testRequestReconnect_setsLastConnectionSucceeded() async {
        let mock = MockSMBClient(status: .ready)
        let service = ConnectionService(smbClient: mock)

        service.requestReconnect(host: "host", sharePath: "/photos", credentials: SMBCredentials(username: "u", password: "p"), initialDelay: .milliseconds(0))

        let ok = await waitFor({ await MainActor.run { service.lastConnectionSucceeded } }, timeout: 1.0)
        XCTAssertTrue(ok, "Reconnect did not complete with success within timeout")
    }

    private func waitFor(_ condition: @escaping @Sendable () async -> Bool, timeout: TimeInterval) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }
}
