import XCTest
@testable import lumvyn

final class SMBClientHelpersTests: XCTestCase {

    func testRenamedPathWithExtension() {
        let result = SMBClient.renamedPath("file.jpg", counter: 2)
        XCTAssertEqual(result, "file-2.jpg")
    }

    func testRenamedPathWithoutExtension() {
        let result = SMBClient.renamedPath("file", counter: 1)
        XCTAssertEqual(result, "file-1")
    }

    func testTempUploadPathPreservesDirAndName() {
        let path = "photos/IMG-001.JPG"
        let temp = SMBClient.tempUploadPath(path)
        XCTAssertTrue(temp.hasSuffix(".IMG-001.JPG.part"))
        XCTAssertTrue(temp.contains("/.lumvyn."))
        XCTAssertTrue(temp.starts(with: "photos/"))
    }

    func testFileSizeReturnsCorrectSize() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("lumvyn_test_size.tmp")
        let data = Data(repeating: 0x41, count: 1234)
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let client = SMBClient()
        let size = try await client.fileSize(tmp)
        XCTAssertEqual(size, Int64(data.count))
    }
}
