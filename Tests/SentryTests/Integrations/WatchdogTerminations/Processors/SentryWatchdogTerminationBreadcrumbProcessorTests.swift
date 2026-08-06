@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class SentryWatchdogTerminationBreadcrumbProcessorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationBreadcrumbProcessorTests.self)

    private final class Fixture {
        let breadcrumb: Breadcrumb
        let invalidJSONBreadcrumb: [String: Double]
        let fileManager: SentryFileManager
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let maxBreadcrumbs = 10

        @available(*, deprecated, message: "Testing deprecated Breadcrumb.data setter")
        init() throws {
            breadcrumb = TestData.crumb
            // swiftlint:disable:next no_breadcrumb_data_setter
            breadcrumb.data = nil
            invalidJSONBreadcrumb = ["invalid": .infinity]

            let options = Options()
            options.dsn = SentryWatchdogTerminationBreadcrumbProcessorTests.dsn
            fileManager = try SentryFileManager(
                options: options,
                dateProvider: TestCurrentDateProvider(),
                dispatchQueueWrapper: TestSentryDispatchQueueWrapper()
            )
        }

        func makeProcessor(
            maxBreadcrumbs: Int? = nil,
            dispatchQueueWrapper: SentryDispatchQueueWrapper? = nil
        ) -> SentryDefaultWatchdogTerminationBreadcrumbProcessor {
            SentryDefaultWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: maxBreadcrumbs ?? self.maxBreadcrumbs,
                fileManager: fileManager,
                dispatchQueueWrapper: dispatchQueueWrapper ?? self.dispatchQueueWrapper
            )
        }
    }

    private var fixture: Fixture!
    private var sut: SentryDefaultWatchdogTerminationBreadcrumbProcessor!

    @available(*, deprecated, message: "Testing deprecated Breadcrumb.data setter")
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        sut = fixture.makeProcessor()
    }

    override func tearDown() {
        fixture.fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testAddSerializedBreadcrumb_withInvalidJSON_shouldNotWriteBreadcrumbFile() {
        // -- Act --
        sut.addSerializedBreadcrumb(fixture.invalidJSONBreadcrumb)

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathOne))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }

    func testAddSerializedBreadcrumb_shouldStoreSerializedBreadcrumb() throws {
        // -- Arrange --
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])

        // -- Act --
        sut.addSerializedBreadcrumb(breadcrumb)

        // -- Assert --
        let contents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        let firstLine = try XCTUnwrap(contents.split(separator: "\n").first)
        let serializedBreadcrumb = try JSONSerialization.jsonObject(with: Data(firstLine.utf8)) as? [String: String]
        XCTAssertEqual(serializedBreadcrumb, breadcrumb)
    }

    func testAddSerializedBreadcrumb_whenMaxBreadcrumbsReached_shouldRotateFiles() throws {
        // -- Arrange --
        let processor = fixture.makeProcessor(maxBreadcrumbs: 2)
        let breadcrumb = fixture.breadcrumb.serialize()

        // -- Act --
        for _ in 0..<3 {
            processor.addSerializedBreadcrumb(breadcrumb)
        }

        // -- Assert --
        let firstFileContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        let secondFileContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(firstFileContents.split(separator: "\n").count, 2)
        XCTAssertEqual(secondFileContents.split(separator: "\n").count, 1)
    }

    func testClearBreadcrumbs_shouldDeleteStoredBreadcrumbs() throws {
        // -- Arrange --
        let breadcrumb = fixture.breadcrumb.serialize()
        sut.addSerializedBreadcrumb(breadcrumb)

        // -- Act --
        sut.clearBreadcrumbs()

        // -- Assert --
        let firstFileContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertTrue(firstFileContents.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }

    func testFlushAndClose_shouldPersistQueuedBreadcrumbsAndIgnoreSubsequentBreadcrumbs() throws {
        // -- Arrange --
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.test-watchdog-breadcrumb-processor")
        let processor = fixture.makeProcessor(dispatchQueueWrapper: dispatchQueue)
        let breadcrumb = fixture.breadcrumb.serialize()

        // -- Act --
        processor.addSerializedBreadcrumb(breadcrumb)
        processor.flushAndClose()
        processor.addSerializedBreadcrumb(breadcrumb)
        dispatchQueue.dispatchSync { }

        // -- Assert --
        let contents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(contents.split(separator: "\n").count, 1)
    }
}
