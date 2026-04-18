import XCTest
@testable import lumvyn

final class FolderTemplateResolverTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func input(
        year: Int = 2024, month: Int = 3, day: Int = 15,
        album: String? = "Holidays",
        isVideo: Bool = false
    ) -> FolderTemplateResolver.Input {
        let cal = utcCalendar()
        let comps = DateComponents(
            calendar: cal, timeZone: cal.timeZone,
            year: year, month: month, day: day, hour: 12
        )
        return FolderTemplateResolver.Input(
            createdAt: comps.date!,
            albumName: album,
            isVideo: isVideo,
            calendar: cal
        )
    }

    func testDefaultTemplateResolvesYearMonth() {
        let result = FolderTemplateResolver.resolve(
            template: FolderTemplateResolver.defaultTemplate,
            input: input()
        )
        XCTAssertEqual(result, "2024/03")
    }

    func testEmptyTemplateReturnsEmpty() {
        XCTAssertEqual(FolderTemplateResolver.resolve(template: "", input: input()), "")
        XCTAssertEqual(FolderTemplateResolver.resolve(template: "   ", input: input()), "")
    }

    func testAllTokensExpandCorrectly() {
        let result = FolderTemplateResolver.resolve(
            template: "{year}/{month}/{day}/{album}/{mediaType}",
            input: input(isVideo: true)
        )
        XCTAssertEqual(result, "2024/03/15/Holidays/videos")
    }

    func testPhotoMediaTypeToken() {
        let result = FolderTemplateResolver.resolve(template: "{mediaType}", input: input(isVideo: false))
        XCTAssertEqual(result, "photos")
    }

    func testMissingAlbumFallsBackToUnsorted() {
        let result = FolderTemplateResolver.resolve(template: "{album}", input: input(album: nil))
        XCTAssertEqual(result, "Unsorted")
    }

    func testZeroPaddedMonthAndDay() {
        let result = FolderTemplateResolver.resolve(
            template: "{year}/{month}/{day}",
            input: input(year: 2024, month: 1, day: 9)
        )
        XCTAssertEqual(result, "2024/01/09")
    }

    func testTokensCombinedWithLiteralText() {
        let result = FolderTemplateResolver.resolve(
            template: "Backup-{year}/Month-{month}",
            input: input()
        )
        XCTAssertEqual(result, "Backup-2024/Month-03")
    }

    func testForbiddenCharactersInAlbumAreStripped() {
        let result = FolderTemplateResolver.resolve(
            template: "{album}",
            input: input(album: "Trip: 2024/summer?")
        )
        // Colon, slash, and question mark replaced with underscore,
        // consecutive forbidden chars collapse to a single underscore.
        XCTAssertEqual(result, "Trip_ 2024_summer_")
    }

    func testTrailingDotsAndSpacesAreTrimmed() {
        let result = FolderTemplateResolver.resolve(
            template: "{album}",
            input: input(album: "Album.  ")
        )
        XCTAssertEqual(result, "Album")
    }

    func testConsecutiveSlashesInTemplateAreCollapsed() {
        let result = FolderTemplateResolver.resolve(
            template: "{year}///{month}",
            input: input()
        )
        XCTAssertEqual(result, "2024/03")
    }

    func testResultNeverHasLeadingOrTrailingSlash() {
        let result = FolderTemplateResolver.resolve(
            template: "/{year}/{month}/",
            input: input()
        )
        XCTAssertFalse(result.hasPrefix("/"))
        XCTAssertFalse(result.hasSuffix("/"))
        XCTAssertEqual(result, "2024/03")
    }

    func testPreviewPathIsNonEmptyForDefaultTemplate() {
        let preview = FolderTemplateResolver.previewPath(template: FolderTemplateResolver.defaultTemplate)
        XCTAssertFalse(preview.isEmpty)
    }
}
