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
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathOne))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }

    // Regression test for https://github.com/getsentry/sentry-cocoa/issues/7794 /
    // https://github.com/getsentry/sentry-cocoa/pull/8653
    //
    // When the SDK restarts (e.g. close() + start(), or start() + start()), the file manager
    // renames the current breadcrumb files to the "previous" paths so the next session can read
    // them. An open FileHandle keeps the underlying inode alive, so any queued async write that
    // executes after the rename lands in the now-previous file, corrupting the breadcrumb history
    // of the new session.
    func testAddSerializedBreadcrumb_afterFileRenamedToPreviewPath_shouldNotWriteIntoPreviousSessionFile() throws {
        // -- Arrange --
        // Use a real async queue so the write is truly deferred.
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.test-watchdog-breadcrumb-processor.restart")
        let processor = fixture.makeProcessor(dispatchQueueWrapper: dispatchQueue)
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])

        // Prime the processor: write one breadcrumb so a file and file handle are open.
        processor.addSerializedBreadcrumb(breadcrumb)
        dispatchQueue.dispatchSync { }

        // -- Act --
        // Suspend the queue so the next write stays pending while we simulate an SDK restart.
        dispatchQueue.queue.suspend()
        processor.addSerializedBreadcrumb(breadcrumb)

        // Simulate what SentrySDK.start() does: rename current breadcrumb files to previous paths.
        fixture.fileManager.moveBreadcrumbsToPreviousBreadcrumbs()

        // Resume the queue — the pending write now executes. With the bug it goes into the
        // previous-session file (via the open inode); with the fix it must not.
        dispatchQueue.queue.resume()
        dispatchQueue.dispatchSync { }

        // -- Assert --
        // The previous-session file must contain exactly the one breadcrumb that was written
        // before the rename — not the one queued after.
        let previousContents = try String(contentsOfFile: fixture.fileManager.previousBreadcrumbsFilePathOne)
        XCTAssertEqual(previousContents.split(separator: "\n").count, 1,
            "Queued write after rename must not land in the previous-session file")

        // The current breadcrumb files for the new session must be empty / absent.
        let currentFileExists = FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertFalse(currentFileExists,
            "No breadcrumb file should exist for the new session since the processor was not re-opened")
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
