import XCTest

class SentryWatchdogTerminationScopeObserverTests: XCTestCase {
    
    private static let dsn = TestConstants.dsnAsString(username: "SentryWatchdogTerminationScopeObserverTests")
    
    private class Fixture {
        let breadcrumb: Breadcrumb
        let options: Options
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let maxBreadcrumbs = 10

        init() {
            breadcrumb = TestData.crumb
            breadcrumb.data = nil

            options = Options()
            options.dsn = SentryWatchdogTerminationScopeObserverTests.dsn
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
        }

        func getSut() -> SentryWatchdogTerminationScopeObserver {
            return getSut(fileManager: self.fileManager)
        }

        func getSut(fileManager: SentryFileManager) -> SentryWatchdogTerminationScopeObserver {
            return SentryWatchdogTerminationScopeObserver(maxBreadcrumbs: maxBreadcrumbs, fileManager: fileManager)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationScopeObserver!

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

        for _ in 0..<9 {
            sut.addSerializedBreadcrumb(breadcrumb)
        }

        var fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        var fileOneLines = fileOneContents.split(separator: "\n")
        XCTAssertEqual(fileOneLines.count, 9)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))

        // Now store one more, which means it'll change over to the second file (which should be empty)
        sut.addSerializedBreadcrumb(breadcrumb)

        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        fileOneLines = fileOneContents.split(separator: "\n")
        XCTAssertEqual(fileOneLines.count, 10)

        var fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents, "")

        // Next one will be stored in the second file
        sut.addSerializedBreadcrumb(breadcrumb)

        fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        var fileTwoLines = fileTwoContents.split(separator: "\n")

        XCTAssertEqual(fileOneLines.count, 10)
        XCTAssertEqual(fileTwoLines.count, 1)

        // Store 10 more
        for _ in 0..<fixture.maxBreadcrumbs {
            sut.addSerializedBreadcrumb(breadcrumb)
        }

        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        fileOneLines = fileOneContents.split(separator: "\n")
        XCTAssertEqual(fileOneLines.count, 1)

        fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        fileTwoLines = fileTwoContents.split(separator: "\n")
        XCTAssertEqual(fileTwoLines.count, 10)
    }

    func testClearBreadcrumbs() throws {
        let breadcrumb = fixture.breadcrumb.serialize()

        for _ in 0..<15 {
            sut.addSerializedBreadcrumb(breadcrumb)
        }

        var fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.count, 1_210)

        let fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents.count, 605)

        sut.clearBreadcrumbs()

        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.count, 0)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }
    
    func testWritingToClosedFile() {
            let breadcrumb = fixture.breadcrumb.serialize() as! [String: String]

            sut.addSerializedBreadcrumb(breadcrumb)

            let fileHandle = Dynamic(sut).fileHandle.asObject as! FileHandle
            fileHandle.closeFile()

            sut.addSerializedBreadcrumb(breadcrumb)

            fixture.fileManager.moveBreadcrumbsToPreviousBreadcrumbs()
            XCTAssertEqual(1, fixture.fileManager.readPreviousBreadcrumbs().count)
        }

        func testWritingToFullFileSystem() {
            let breadcrumb = fixture.breadcrumb.serialize() as! [String: String]

            sut.addSerializedBreadcrumb(breadcrumb)

            // "/dev/urandom" simulates a bad file descriptor
            let fileHandle = FileHandle(forReadingAtPath: "/dev/urandom")
            Dynamic(sut).fileHandle = fileHandle

            sut.addSerializedBreadcrumb(breadcrumb)

            fixture.fileManager.moveBreadcrumbsToPreviousBreadcrumbs()
            XCTAssertEqual(1, fixture.fileManager.readPreviousBreadcrumbs().count)
        }
}
