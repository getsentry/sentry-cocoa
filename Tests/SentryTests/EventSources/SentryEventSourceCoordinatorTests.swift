@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryEventSourceCoordinatorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryEventSourceCoordinatorTests.self)

    private var fileManager: SentryFileManager!
    private var dateProvider: TestCurrentDateProvider!
    private var store: SentryFatalRunRecordStore!
    private var downstream: TestEventSourceSink!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsn
        dateProvider = TestCurrentDateProvider()
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        store = SentryFatalRunRecordStore(fileManager: fileManager, dateProvider: dateProvider)
        downstream = TestEventSourceSink()
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    // MARK: - Forwarding

    func testIsAvailable_whenDownstreamIsAvailable_shouldReturnTrue() {
        // -- Arrange --
        let sut = givenSut()

        // -- Act & Assert --
        XCTAssertTrue(sut.isAvailable)
    }

    func testIsAvailable_whenDownstreamIsUnavailable_shouldReturnFalse() {
        // -- Arrange --
        downstream.isAvailable = false
        let sut = givenSut()

        // -- Act & Assert --
        XCTAssertFalse(sut.isAvailable)
    }

    func testSubmit_whenDownstreamAccepts_shouldForwardReportUnchanged() throws {
        // -- Arrange --
        let sut = givenSut()
        let event = Event(level: .error)
        let attachment = Attachment(data: Data("diagnostic".utf8), filename: "diagnostic.json")
        let report = SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [attachment], runEnd: nil),
            runId: nil,
            event: event
        )

        // -- Act --
        let result = sut.submit(report)

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 1)
        let forwarded = try XCTUnwrap(downstream.submittedReports.first)
        XCTAssertEqual(forwarded.source, .metricKit)
        XCTAssertIdentical(forwarded.event, event)
        guard case .diagnostic(let attachments, let runEnd) = forwarded.kind else {
            return XCTFail("Expected a diagnostic report")
        }
        XCTAssertEqual(attachments.count, 1)
        XCTAssertIdentical(attachments.first, attachment)
        XCTAssertNil(runEnd)
    }

    func testSubmit_whenDownstreamIsUnavailable_shouldReturnUnavailable() {
        // -- Arrange --
        downstream.isAvailable = false
        let sut = givenSut()

        // -- Act --
        let result = sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(downstream.submittedReports.count, 0)
    }

    func testSubmit_whenSourceWithdrawsReport_shouldReturnWithdrawn() {
        // -- Arrange --
        let sut = givenSut()
        var beforeAcceptingInvocations = 0

        // -- Act --
        let result = sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1")) {
            beforeAcceptingInvocations += 1
            return false
        }

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertEqual(beforeAcceptingInvocations, 1)
        XCTAssertEqual(downstream.submittedReports.count, 0)
    }

    // MARK: - Recording fatal runs

    func testSubmit_whenFatalReportOfCrashHandlerIsAccepted_shouldRecordRunAsReportedByCrashHandler() throws {
        // -- Arrange --
        let sut = givenSut()

        // -- Act --
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))

        // -- Assert --
        let record = try XCTUnwrap(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1")))
        XCTAssertEqual(record.reportedBy, .crashHandler)
        XCTAssertEqual(record.date, dateProvider.date())
    }

    func testSubmit_whenFatalReportOfWatchdogIsAccepted_shouldRecordRunAsReportedByWatchdog() throws {
        // -- Arrange --
        let sut = givenSut()

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1"))).reportedBy, .watchdogTermination)
    }

    func testSubmit_whenFatalReportIsNotAccepted_shouldNotRecordRun() {
        // -- Arrange --
        downstream.isAvailable = false
        let sut = givenSut()

        // -- Act --
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))

        // -- Assert --
        XCTAssertNil(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1")))
    }

    func testSubmit_whenFatalReportHasNoRunId_shouldNotRecordRun() {
        // -- Arrange --
        let sut = givenSut()

        // -- Act --
        sut.submit(givenFatalReport(source: .crashHandler, runId: nil))

        // -- Assert --
        XCTAssertEqual(store.records(), [])
    }

    func testSubmit_whenDiagnosticReportIsAccepted_shouldNotRecordRun() {
        // -- Arrange --
        let sut = givenSut()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(store.records(), [])
    }

    // MARK: - Dropping duplicate crashes

    func testSubmit_whenCrashDiagnosticDescribesRunReportedByCrashHandler_shouldDropItAsAccepted() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.submittedReports.removeAll()
        var beforeAcceptingInvocations = 0

        // -- Act --
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash)) {
            beforeAcceptingInvocations += 1
            return true
        }

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 0)
        XCTAssertEqual(beforeAcceptingInvocations, 0)
    }

    func testSubmit_whenCrashDiagnosticDescribesRunRecordedInAnEarlierLaunch_shouldDropIt() {
        // -- Arrange --
        // The record was written by a coordinator of an earlier launch.
        store.add(SentryFatalRunRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), reportedBy: .crashHandler, date: dateProvider.date()))
        dateProvider.advance(by: 24 * 60 * 60)
        let sut = givenSut()

        // -- Act --
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 0)
    }

    func testSubmit_whenCrashDiagnosticDescribesRunReportedByWatchdog_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))
        downstream.submittedReports.removeAll()

        // -- Act --
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenMemoryDiagnosticDescribesRunReportedByCrashHandler_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.submittedReports.removeAll()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .memoryTermination))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenDiagnosticDoesNotEndRunReportedByCrashHandler_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.submittedReports.removeAll()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: nil))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenCrashDiagnosticHasNoRunId_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.submittedReports.removeAll()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: nil, runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenCrashDiagnosticDescribesUnrecordedRun_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.submittedReports.removeAll()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-2", runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenCrashHandlerReportWasNotAccepted_shouldForwardCrashDiagnosticOfItsRun() {
        // -- Arrange --
        downstream.isAvailable = false
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.isAvailable = true

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenThereIsNoStore_shouldForwardEveryReport() {
        // -- Arrange --
        let sut = SentryEventSourceCoordinator(downstream: downstream, fatalRunRecordStore: nil, dateProvider: dateProvider)
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 2)
    }

    // MARK: - Helpers

    private func givenSut() -> SentryEventSourceCoordinator {
        SentryEventSourceCoordinator(downstream: downstream, fatalRunRecordStore: store, dateProvider: dateProvider)
    }

    private func givenFatalReport(source: SentryEventSource, runId: String?) -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: source,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: source == .crashHandler),
            runId: runId.map { SentryCurrentRun.ID(rawValue: $0) },
            event: Event(level: .fatal)
        )
    }

    private func givenDiagnosticReport(runId: String?, runEnd: SentryEventSourceReport.RunEnd?) -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [], runEnd: runEnd),
            runId: runId.map { SentryCurrentRun.ID(rawValue: $0) },
            event: Event(level: .error)
        )
    }
}
