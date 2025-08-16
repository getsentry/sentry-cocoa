@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryWatchdogTerminationBreadcrumbProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationBreadcrumbProcessorTests.self)

    private class Fixture {
        let breadcrumb: Breadcrumb
        let invalidJSONbreadcrumb: [String: Double]
        let options: Options
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let maxBreadcrumbs = 10

        init() {
            breadcrumb = TestData.crumb
            breadcrumb.data = nil

            invalidJSONbreadcrumb = [ "invalid": Double.infinity ]

            options = Options()
            options.dsn = SentryWatchdogTerminationBreadcrumbProcessorTests.dsn
            fileManager = try! SentryFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )
        }

        func getSut() -> SentryWatchdogTerminationBreadcrumbProcessor {
            return getSut(fileManager: self.fileManager)
        }

        func getSut(fileManager: SentryFileManager) -> SentryWatchdogTerminationBreadcrumbProcessor {
            return SentryWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: maxBreadcrumbs,
                fileManager: fileManager
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationBreadcrumbProcessor!

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
    func testAddSerializedBreadcrumb_withInvalidJSON_shouldNotBeWrittenToFile() throws {
        // -- Arrange --
        let breadcrumb = fixture.invalidJSONbreadcrumb

        // -- Act --
        sut.addSerializedBreadcrumb(breadcrumb)

        // -- Assert --
        let fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        let fileOneFirstLine = fileOneContents.split(separator: "\n").first
        XCTAssertNil(fileOneFirstLine)

        let fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        let fileTwoFirstLine = fileTwoContents.split(separator: "\n").first
        XCTAssertNil(fileTwoFirstLine)
    }

    // Test that we're storing the serialized breadcrumb in a proper JSON string
    func testStoreBreadcrumb() throws {
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])

        sut.addSerializedBreadcrumb(breadcrumb)

        let fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        let firstLine = String(fileOneContents.split(separator: "\n").first!)
        let dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: firstLine.data(using: .utf8)!) as? [String: String])

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

    func testClear_shouldClearBreadcrumbs() throws {
        // -- Arrange --
        let breadcrumb = fixture.breadcrumb.serialize()

        for _ in 0..<15 {
            sut.addSerializedBreadcrumb(breadcrumb)
        }

        // Check pre-conditions
        var fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.count, 1_210)

        let fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents.count, 605)

        // -- Act --
        sut.clear()

        // -- Assert --
        fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.count, 0)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }

    func testWritingToClosedFile() throws {
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])

        sut.addSerializedBreadcrumb(breadcrumb)

        let fileHandle = try XCTUnwrap(Dynamic(sut).fileHandle.asObject as? FileHandle)
        fileHandle.closeFile()

        sut.addSerializedBreadcrumb(breadcrumb)

        fixture.fileManager.moveBreadcrumbsToPreviousBreadcrumbs()
        XCTAssertEqual(1, fixture.fileManager.readPreviousBreadcrumbs().count)
    }

    func testWritingToFullFileSystem() throws {
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])

        sut.addSerializedBreadcrumb(breadcrumb)

        // "/dev/urandom" simulates a bad file descriptor
        let fileHandle = FileHandle(forReadingAtPath: "/dev/urandom")
        Dynamic(sut).fileHandle = fileHandle

        sut.addSerializedBreadcrumb(breadcrumb)

        fixture.fileManager.moveBreadcrumbsToPreviousBreadcrumbs()
        XCTAssertEqual(1, fixture.fileManager.readPreviousBreadcrumbs().count)
    }
}
