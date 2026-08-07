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
    //
    // flushAndClose() fixes this by draining all pending writes and closing the file
    // handle before performing the rename — all inside a single dispatchSync barrier on the
    // processor's serial queue. This guarantees no queued write can follow the inode after rename.
    func testFlushAndClose_drainsQueueBeforeRename() throws {
        // -- Arrange --
        // Use a real async queue so writes are truly deferred.
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.test-watchdog-breadcrumb-processor.restart")
        let processor = fixture.makeProcessor(dispatchQueueWrapper: dispatchQueue)
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])

        // -- Act --
        // Queue two breadcrumb writes without waiting for them to execute.
        processor.addSerializedBreadcrumb(breadcrumb)
        processor.addSerializedBreadcrumb(breadcrumb)

        // flushAndClose() issues a dispatchSync barrier: it waits for both queued writes to
        // complete first, then closes the handle and renames the files.
        // No write can land in the previous-session file via a stale descriptor.
        processor.flushAndClose()

        // -- Assert --
        // Both breadcrumbs must be in the previous-session file (they were written before rename).
        let previousContents = try String(contentsOfFile: fixture.fileManager.previousBreadcrumbsFilePathOne)
        XCTAssertEqual(previousContents.split(separator: "\n").count, 2,
            "Both queued writes must complete before the rename and land in the previous-session file")

        // The current breadcrumb files for the new session must be absent.
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathOne),
            "No breadcrumb file should exist for the new session yet")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo),
            "No breadcrumb file two should exist for the new session yet")
    }

    func testFlushAndClose_shouldPersistQueuedBreadcrumbsAndIgnoreSubsequentBreadcrumbs() throws {
        // -- Arrange --
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.test-watchdog-breadcrumb-processor")
        let processor = fixture.makeProcessor(dispatchQueueWrapper: dispatchQueue)
        let breadcrumb = fixture.breadcrumb.serialize()

        // -- Act --
        processor.addSerializedBreadcrumb(breadcrumb)
        processor.flushAndClose()
        // This write must be ignored — the processor is closed.
        processor.addSerializedBreadcrumb(breadcrumb)
        dispatchQueue.dispatchSync { }

        // -- Assert --
        // The breadcrumb written before close must be in the previous-session file.
        let previousContents = try String(contentsOfFile: fixture.fileManager.previousBreadcrumbsFilePathOne)
        XCTAssertEqual(previousContents.split(separator: "\n").count, 1,
            "Only the breadcrumb written before flushAndClose should be persisted")
        // The current file must not exist — the write after close was dropped.
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathOne),
            "No write should have occurred after flushAndClose")
    }
}
