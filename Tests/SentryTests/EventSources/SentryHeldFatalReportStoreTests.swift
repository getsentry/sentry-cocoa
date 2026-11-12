@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryHeldFatalReportStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryHeldFatalReportStoreTests.self)

    private var fileManager: SentryFileManager!
    private var sut: SentryHeldFatalReportStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsn
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        sut = SentryHeldFatalReportStore(fileManager: fileManager)
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testRead_whenReportWasStored_shouldReturnItWithItsEvent() throws {
        // -- Arrange --
        let event = Event(level: .fatal)
        event.timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        event.tags = ["previous": "run"]
        event.breadcrumbs = [Breadcrumb(level: .info, category: "ui")]
        let exception = Exception(value: "value", type: "WatchdogTermination")
        exception.mechanism = Mechanism(type: "watchdog_termination")
        event.exceptions = [exception]
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: event))

        // -- Act --
        let read = try XCTUnwrap(sut.read())

        // -- Assert --
        XCTAssertEqual(read.runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertEqual(read.source, .watchdogTermination)
        XCTAssertEqual(read.event.eventId, event.eventId)
        XCTAssertEqual(read.event.level, .fatal)
        XCTAssertEqual(read.event.timestamp, event.timestamp)
        XCTAssertEqual(read.event.tags, ["previous": "run"])
        XCTAssertEqual(read.event.breadcrumbs?.count, 1)
        XCTAssertEqual(read.event.exceptions?.first?.type, "WatchdogTermination")
        XCTAssertEqual(read.event.exceptions?.first?.mechanism?.type, "watchdog_termination")
    }

    func testRead_whenStoredEventHasNoBreadcrumbs_shouldReturnEmptyBreadcrumbs() throws {
        // -- Arrange --
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Act --
        let read = try XCTUnwrap(sut.read())

        // -- Assert --
        XCTAssertEqual(read.event.breadcrumbs?.count, 0)
    }

    func testRead_whenNothingWasStored_shouldReturnNil() {
        // -- Act & Assert --
        XCTAssertNil(sut.read())
    }

    func testRead_whenFileIsCorrupt_shouldReturnNilAndDeleteIt() throws {
        // -- Arrange --
        fileManager.write(Data("not json".utf8), toPath: sut.filePath)

        // -- Act --
        let read = sut.read()

        // -- Assert --
        XCTAssertNil(read)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sut.filePath))
    }

    func testStore_whenReportIsHeld_shouldReplaceIt() throws {
        // -- Arrange --
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Act --
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-2"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.read()).runId, SentryCurrentRun.ID(rawValue: "run-2"))
    }

    func testDelete_whenReportIsHeld_shouldRemoveIt() {
        // -- Arrange --
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Act --
        sut.delete()

        // -- Assert --
        XCTAssertNil(sut.read())
    }

    func testReport_whenRead_shouldBeAFatalReportWithoutAttachments() throws {
        // -- Arrange --
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Act --
        let report = try XCTUnwrap(sut.read()).report

        // -- Assert --
        XCTAssertEqual(report.source, .watchdogTermination)
        XCTAssertEqual(report.runId, SentryCurrentRun.ID(rawValue: "run-1"))
        guard case .fatal(let attachmentPaths, let isRetainedOnFailure) = report.kind else {
            return XCTFail("Expected a fatal report")
        }
        XCTAssertEqual(attachmentPaths, [])
        XCTAssertFalse(isRetainedOnFailure)
    }

    // MARK: - Crashed session

    func testRead_whenReportWasStoredWithSession_shouldReturnItsSession() throws {
        // -- Arrange --
        let session = givenCrashedSession()
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal), session: session))

        // -- Act --
        let read = try XCTUnwrap(sut.read())

        // -- Assert --
        XCTAssertEqual(read.session?.sessionId, session.sessionId)
        XCTAssertEqual(read.session?.status, .crashed)
    }

    func testReport_whenReportWasStoredWithSession_shouldCarryItsSession() throws {
        // -- Arrange --
        let session = givenCrashedSession()
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal), session: session))

        // -- Act --
        let report = try XCTUnwrap(sut.read()).report

        // -- Assert --
        guard case let .carried(carried) = report.crashedSession else {
            return XCTFail("Expected the report to carry its session")
        }
        XCTAssertEqual(carried?.sessionId, session.sessionId)
    }

    func testReport_whenReportWasStoredWithoutSession_shouldCarryNoSession() throws {
        // -- Arrange --
        sut.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Act --
        let report = try XCTUnwrap(sut.read()).report

        // -- Assert --
        guard case let .carried(carried) = report.crashedSession else {
            return XCTFail("Expected the report not to take the session stored for the previous run")
        }
        XCTAssertNil(carried)
    }

    func testStoreTakingCrashedSession_whenCrashedSessionIsStored_shouldMoveItIntoTheReport() throws {
        // -- Arrange --
        let session = givenCrashedSession()
        fileManager.storeCrashedSession(session)

        // -- Act --
        sut.storeTakingCrashedSession(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(sut.read()).session?.sessionId, session.sessionId)
        XCTAssertNil(fileManager.readCrashedSession())
    }

    func testStoreTakingCrashedSession_whenNoCrashedSessionIsStored_shouldStoreReportWithoutSession() throws {
        // -- Act --
        sut.storeTakingCrashedSession(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Assert --
        XCTAssertNil(try XCTUnwrap(sut.read()).session)
    }

    // MARK: - Helpers

    private func givenCrashedSession() -> SentrySession {
        let session = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        session.endCrashed(withTimestamp: Date(timeIntervalSince1970: 1_700_000_000))
        return session
    }
}
