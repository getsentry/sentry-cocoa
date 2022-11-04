import XCTest

class SentryOutOfMemoryScopeObserverTests: XCTestCase {
    private class Fixture {
        let breadcrumb: Breadcrumb
        let options: Options
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()

        init() {
            breadcrumb = Breadcrumb()
            breadcrumb.level = SentryLevel.info
            breadcrumb.timestamp = Date(timeIntervalSince1970: 10)
            breadcrumb.category = "category"
            breadcrumb.type = "user"
            breadcrumb.message = "Click something"

            options = Options()
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
        }

        func getSut() -> SentryOutOfMemoryScopeObserver {
            return getSut(fileManager: self.fileManager)
        }

        func getSut(fileManager: SentryFileManager) -> SentryOutOfMemoryScopeObserver {
            return SentryOutOfMemoryScopeObserver(maxBreadcrumbs: 10, fileManager: fileManager)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryOutOfMemoryScopeObserver!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
        sut = fixture.getSut()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAllFolders()
    }

    // Test that we're storing the serialized breadcrumb in a proper JSON string
    func testStoreBreadcrumb() throws {
        let breadcrumb = fixture.breadcrumb.serialize() as! [String: String]

        sut.addSerializedBreadcrumb(breadcrumb)

        let fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        let firstLine = String(fileOneContents.split(separator: "\n").first!)
        let dict = try JSONSerialization.jsonObject(with: firstLine.data(using: .utf8)!) as! [String: String]

        XCTAssertEqual(dict, breadcrumb)
    }

    func testStoreInMultipleFiles() throws {
        let breadcrumb = fixture.breadcrumb.serialize()

        var count = 0
        while count < 9 {
            sut.addSerializedBreadcrumb(breadcrumb)
            count += 1
        }

        var fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        var fileOnelines = fileOneContents.split(separator: "\n")
        XCTAssertEqual(fileOnelines.count, 9)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))

        // Now store one more, which means it'll change over to the second file (which should be empty)
        sut.addSerializedBreadcrumb(breadcrumb)

        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        fileOnelines = fileOneContents.split(separator: "\n")
        XCTAssertEqual(fileOnelines.count, 10)

        var fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents, "")

        // Next one will be stored in the second file
        sut.addSerializedBreadcrumb(breadcrumb)

        fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        var fileTwolines = fileTwoContents.split(separator: "\n")

        XCTAssertEqual(fileOnelines.count, 10)
        XCTAssertEqual(fileTwolines.count, 1)

        // Store 10 more
        count = 0
        while count < 10 {
            sut.addSerializedBreadcrumb(breadcrumb)
            count += 1
        }

        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        fileOnelines = fileOneContents.split(separator: "\n")
        XCTAssertEqual(fileOnelines.count, 1)

        fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        fileTwolines = fileTwoContents.split(separator: "\n")
        XCTAssertEqual(fileTwolines.count, 10)
    }

    func testClearBreadcrumbs() throws {
        let breadcrumb = fixture.breadcrumb.serialize()

        var count = 0
        while count < 15 {
            sut.addSerializedBreadcrumb(breadcrumb)
            count += 1
        }

        var fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.count, 1_200)

        let fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents.count, 600)

        sut.clearBreadcrumbs()

        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.count, 0)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }
}
