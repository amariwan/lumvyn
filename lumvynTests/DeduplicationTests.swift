import XCTest
@testable import lumvyn

final class DeduplicationTests: XCTestCase {

    func testMarkUploadedAndPersistence() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dedup-test-\(UUID().uuidString).json")
        try? FileManager.default.removeItem(at: url)

        let service = DeduplicationService(storageURL: url)

        XCTAssertFalse(await service.contains("abc"))

        await service.markUploaded(fingerprint: "abc")

        // Give the background persist queue a moment to write the file
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(await service.contains("abc"))

        let data = try Data(contentsOf: url)
        let arr = try JSONDecoder().decode([String].self, from: data)
        XCTAssertTrue(arr.contains("abc"))

        try? FileManager.default.removeItem(at: url)
    }

    func testLoadFromExistingFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dedup-test-\(UUID().uuidString).json")
        try? FileManager.default.removeItem(at: url)

        let known = ["fp1", "fp2", "fp3"]
        let data = try JSONEncoder().encode(known.sorted())
        try data.write(to: url, options: [.atomic])

        let service = DeduplicationService(storageURL: url)
        XCTAssertTrue(await service.contains("fp1"))
        XCTAssertTrue(await service.contains("fp2"))
        XCTAssertFalse(await service.contains("does-not-exist"))

        try? FileManager.default.removeItem(at: url)
    }
}
