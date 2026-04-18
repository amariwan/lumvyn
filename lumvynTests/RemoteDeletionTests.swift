import XCTest
@testable import lumvyn

final class RemoteDeletionTests: XCTestCase {

    final class RecordingSMBClient: SMBClientProtocol {
        var deleted: [(host: String, sharePath: String, remotePath: String)] = []

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

        func testConnection(host: String, sharePath: String, credentials: SMBCredentials?) async throws {}
        func connectionStatus(host: String, sharePath: String, credentials: SMBCredentials?) async -> SMBConnectionStatus { .ready }
        func probeWrite(host: String, sharePath: String, credentials: SMBCredentials) async throws {}

        func listShares(host: String, credentials: SMBCredentials?) async throws -> [SMBShare] { [] }
        func listDirectories(host: String, shareName: String, path: String, credentials: SMBCredentials?) async throws -> [String] { [] }
        func listDirectoryItems(host: String, shareName: String, path: String, credentials: SMBCredentials?) async throws -> [SMBDirectoryEntry] { [] }

        func deleteRemoteItem(host: String, sharePath: String, remotePath: String, credentials: SMBCredentials?) async throws {
            deleted.append((host: host, sharePath: sharePath, remotePath: remotePath))
        }

        func downloadFile(host: String, shareName: String, remotePath: String, credentials: SMBCredentials?) async throws -> URL {
            throw NSError(domain: "Mock", code: 1, userInfo: nil)
        }
    }

    func testRemoteIndexStore_save_and_remove() async {
        let store = RemoteIndexStore(fileName: "remote-index-test.json")
        let localId = "local-1"
        await store.saveMapping(localId: localId, host: "h", sharePath: "/s", remotePath: "/s/f.jpg", fingerprint: "fp")
        let entry = await store.mapping(for: localId)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.host, "h")
        XCTAssertEqual(entry?.remotePath, "/s/f.jpg")

        await store.removeMapping(localId: localId)
        let after = await store.mapping(for: localId)
        XCTAssertNil(after)
    }

    func testRemoteDeletionQueue_processPending_removes_entry() async {
        let dq = RemoteDeletionQueue(fileName: "remote-deletion-queue-test.json")
        await dq.enqueue(localId: "a1", host: "h", sharePath: "/s", remotePath: "/s/f.jpg")
        let pendingBefore = await dq.pendingCount()
        XCTAssertEqual(pendingBefore, 1)

        let client = RecordingSMBClient()
        let result = await dq.processPending(smbClient: client, credentials: nil, remoteIndex: nil)

        let pendingAfter = await dq.pendingCount()
        XCTAssertEqual(pendingAfter, 0)
        XCTAssertEqual(client.deleted.count, 1)
        XCTAssertEqual(client.deleted.first?.remotePath, "/s/f.jpg")
        XCTAssertEqual(result.deleted, 1)
        XCTAssertEqual(result.failed, 0)
    }
}
