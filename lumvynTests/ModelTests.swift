import XCTest
@testable import lumvyn

final class ModelTests: XCTestCase {

    func testDateRangeOptionCustomValidity() {
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 2000)
        var option = DateRangeOption(type: .custom, startDate: start, endDate: end)
        XCTAssertTrue(option.isValid)
        option.startDate = Date(timeIntervalSince1970: 3000)
        XCTAssertFalse(option.isValid)
    }

    func testDateRangeOptionMatches() {
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 2000)
        let option = DateRangeOption(type: .custom, startDate: start, endDate: end)
        XCTAssertTrue(option.matches(Date(timeIntervalSince1970: 1500)))
        XCTAssertFalse(option.matches(Date(timeIntervalSince1970: 2500)))
        XCTAssertFalse(option.matches(Date(timeIntervalSince1970: 500)))
    }

    func testSMBServerConfigValidity() {
        var config = SMBServerConfig()
        XCTAssertFalse(config.isValid)
        config.host = "example.com"
        config.sharePath = "/share"
        XCTAssertTrue(config.isValid)
        config.host = "   "
        XCTAssertFalse(config.isValid)
    }

    func testUploadItemCodableRoundtrip() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let item = UploadItem(
            assetLocalIdentifier: "abc",
            fileName: "image.jpg",
            mediaType: .photo,
            createdAt: createdAt,
            albumName: "Album",
            locationName: "Place",
            isFavorite: true,
            isHidden: false,
            pixelWidth: 100,
            pixelHeight: 200,
            sourceType: "library",
            subtypes: ["sub1"],
            burstIdentifier: nil,
            fileSize: 12345,
            fingerprint: "fp",
            priority: 1,
            assetDuration: nil
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(UploadItem.self, from: data)
        XCTAssertEqual(item, decoded)
    }

    func testUploadItemDecodesLegacyLocalizedMediaType() throws {
        let json = #"[
            {
                "id": "00000000-0000-0000-0000-000000000000",
                "assetLocalIdentifier": "abc",
                "fileName": "video.mov",
                "mediaType": "Video",
                "createdAt": 1700000000,
                "albumName": "Album",
                "locationName": "Place",
                "isFavorite": false,
                "isHidden": false,
                "pixelWidth": 1920,
                "pixelHeight": 1080,
                "sourceType": "library",
                "subtypes": [],
                "burstIdentifier": null,
                "fileSize": 123456,
                "fingerprint": null,
                "priority": 1,
                "status": "pending",
                "progress": 0.0,
                "retryCount": 0,
                "lastError": null,
                "assetDuration": 15.0
            }
        ]"#
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode([UploadItem].self, from: data)
        XCTAssertEqual(decoded.first?.mediaType, .video)
    }
}
