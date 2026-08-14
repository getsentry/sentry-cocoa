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

    func testSwitchCurrentFilePath_fromFileOneToFileTwo_shouldWriteToFileTwo() throws {
        // -- Arrange --
        let processor = fixture.makeProcessor(maxBreadcrumbs: 2)
        let breadcrumb = fixture.breadcrumb.serialize()

        // Fill file one to capacity to trigger the first rotation.
        for _ in 0..<2 { processor.addSerializedBreadcrumb(breadcrumb) }

        // -- Act --
        // This breadcrumb is written after the rotation: currentFilePath must now be filePathTwo.
        processor.addSerializedBreadcrumb(breadcrumb)

        // -- Assert --
        let fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents.split(separator: "\n").count, 1,
            "After first rotation, writes must go to breadcrumbsFilePathTwo")
    }

    func testSwitchCurrentFilePath_fromFileTwoBackToFileOne_shouldWriteToFileOne() throws {
        // -- Arrange --
        let processor = fixture.makeProcessor(maxBreadcrumbs: 2)
        let breadcrumb = fixture.breadcrumb.serialize()

        // Fill file one (triggers rotation to file two), then fill file two (triggers rotation back).
        for _ in 0..<4 { processor.addSerializedBreadcrumb(breadcrumb) }

        // -- Act --
        // This breadcrumb is written after the second rotation: currentFilePath must be filePathOne again.
        processor.addSerializedBreadcrumb(breadcrumb)

        // -- Assert --
        // File one was cleared by the second rotation and now holds just this one breadcrumb.
        let fileOneContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(fileOneContents.split(separator: "\n").count, 1,
            "After second rotation, writes must wrap back to breadcrumbsFilePathOne")
        // File two still holds the two breadcrumbs from the first cycle.
        let fileTwoContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathTwo)
        XCTAssertEqual(fileTwoContents.split(separator: "\n").count, 2,
            "breadcrumbsFilePathTwo must still contain the breadcrumbs from the first rotation cycle")
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
    // later renames the current breadcrumb files to the "previous" paths so the next session can
    // read them. An open FileHandle keeps the underlying inode alive, so any queued async write
    // that executes after that rename would land in the now-previous file and corrupt the new
    // session's breadcrumb history.
    //
    // flushAndClose() drains all pending writes and closes the file handle inside a single
    // dispatchSync barrier on the processor's serial queue. Session rotation stays with the SDK
    // start path, after this handle is already closed.
    func testFlushAndClose_drainsQueueAndLeavesCurrentFilesInPlace() throws {
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
        // complete first, then closes the handle without rotating files.
        processor.flushAndClose()

        // -- Assert --
        // Both breadcrumbs must be in the current-session file (they were written before close).
        let currentContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(currentContents.split(separator: "\n").count, 2,
            "Both queued writes must complete before close and stay in the current-session file")

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.previousBreadcrumbsFilePathOne),
            "flushAndClose must not rotate breadcrumbs to the previous-session path")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.previousBreadcrumbsFilePathTwo),
            "flushAndClose must not rotate breadcrumb file two to the previous-session path")
    }

    func testClear_shouldDelegateToClearBreadcrumbs() throws {
        // -- Arrange --
        let breadcrumb = fixture.breadcrumb.serialize()
        sut.addSerializedBreadcrumb(breadcrumb)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathOne),
            "clear() must delete breadcrumb files just like clearBreadcrumbs()")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.breadcrumbsFilePathTwo))
    }

    func testClearBreadcrumbs_thenAddSerializedBreadcrumb_shouldWriteToFreshFile() throws {
        // -- Arrange --
        let breadcrumb = try XCTUnwrap(fixture.breadcrumb.serialize() as? [String: String])
        sut.addSerializedBreadcrumb(breadcrumb)
        sut.clearBreadcrumbs()

        // -- Act --
        sut.addSerializedBreadcrumb(breadcrumb)

        // -- Assert --
        // The processor must re-create the file and write the new breadcrumb cleanly.
        let contents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(contents.split(separator: "\n").count, 1,
            "A write after clearBreadcrumbs must create a new file with exactly one breadcrumb")
    }

    func testFlushAndClose_calledTwice_shouldBeIdempotent() throws {
        // -- Arrange --
        let dispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.test-watchdog-breadcrumb-processor.idempotent")
        let processor = fixture.makeProcessor(dispatchQueueWrapper: dispatchQueue)
        let breadcrumb = fixture.breadcrumb.serialize()
        processor.addSerializedBreadcrumb(breadcrumb)

        // -- Act --
        processor.flushAndClose()  // first call: drains writes and closes handle
        processor.flushAndClose()  // second call: must be a no-op

        // -- Assert --
        // The current-session file must still contain exactly the one breadcrumb from the first call.
        let currentContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(currentContents.split(separator: "\n").count, 1,
            "Second flushAndClose must not alter the current-session file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.previousBreadcrumbsFilePathOne),
            "flushAndClose must not rotate breadcrumbs to the previous-session path")
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
        // The breadcrumb written before close must stay in the current-session file.
        let currentContents = try String(contentsOfFile: fixture.fileManager.breadcrumbsFilePathOne)
        XCTAssertEqual(currentContents.split(separator: "\n").count, 1,
            "Only the breadcrumb written before flushAndClose should be persisted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileManager.previousBreadcrumbsFilePathOne),
            "flushAndClose must not rotate breadcrumbs to the previous-session path")
    }
}
