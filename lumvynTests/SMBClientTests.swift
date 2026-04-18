import XCTest
@testable import lumvyn

final class SMBClientTests: XCTestCase {

    final class FailingSMBClient: SMBClientProtocol {
        func upload(
            fileURL: URL,
            to remotePath: String,
            host: String,
            sharePath: String,
            credentials: SMBCredentials,
            conflictResolution: ConflictResolution,
            progress: @escaping @Sendable (Double) -> Void
        ) async throws -> String {
            throw SMBClientError.uploadFailed(NSError(domain: "Mock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock upload failed"]))
        }

        func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {
            throw SMBClientError.connectionFailed(NSError(domain: "Mock", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock failure"]))
        }

        func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus {
            return .failed("Mock failure")
        }

        func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {
            throw SMBClientError.uploadFailed(NSError(domain: "Mock", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock write failed"]))
        }
    }

    func testUploadThrowsUploadNotAvailable() async {
        let client = FailingSMBClient()
        do {
            try await client.upload(
                fileURL: URL(fileURLWithPath: "/dev/null"),
                to: "/remote/path",
                host: "example.com",
                sharePath: "/share",
                credentials: SMBCredentials(username: "u", password: "p"),
                conflictResolution: .rename,
                progress: { _ in }
            )
            XCTFail("Expected upload to throw")
        } catch {
            guard let smbError = error as? SMBClientError else {
                XCTFail("Expected SMBClientError")
                return
            }
            switch smbError {
            case .uploadFailed:
                break // expected
            default:
                XCTFail("Expected uploadFailed, got \(smbError)")
            }
        }
    }

    func testSMBClientErrorDescription() {
        let errors: [SMBClientError] = [
            .notConfigured,
            .connectionFailed(NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "x"])),
            .timedOut(host: "h"),
            .uploadFailed(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "y"]))
        ]
        for err in errors {
            XCTAssertNotNil(err.errorDescription)
        }
    }
}
