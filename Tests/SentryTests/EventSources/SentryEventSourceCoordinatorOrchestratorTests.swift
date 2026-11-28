@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

/// How the coordinator applies the orchestrators it is given. `SentryEventSourceCoordinatorTests`
/// covers holding and sending with the orchestrator of watchdog terminations and MetricKit.
final class SentryEventSourceCoordinatorOrchestratorTests: XCTestCase {
    private var fileManager: SentryFileManager!
    private var heldReportStore: SentryHeldFatalReportStore!
    private var downstream: TestEventSourceSink!
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: SentryEventSourceCoordinatorOrchestratorTests.self)
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: TestCurrentDateProvider(), dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        heldReportStore = SentryHeldFatalReportStore(fileManager: fileManager)
        downstream = TestEventSourceSink()
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        dispatchQueueWrapper.dispatchAfterExecutesBlock = false
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testSubmit_whenNoOrchestratorAwaitsTheDiagnosticsSource_shouldForwardItAndKeepHolding() throws {
        // -- Arrange --
        let sut = givenSut(heldFatalReportStore: heldReportStore)
        sut.use([SentryEventSourceOrchestrator(heldSource: .watchdogTermination, awaitedSource: .crashHandler, holdDuration: 30) { held, _, _ in held.event }])
        sut.submit(givenWatchdogTerminationReport())

        // -- Act --
        sut.submit(givenDiagnosticReport(runEnd: .crash(terminationReason: nil)))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).source, .metricKit)
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testSubmit_whenDiagnosticDescribesHeldRun_shouldSendTheEventTheOrchestratorMerges() throws {
        // -- Arrange --
        let sut = givenSut(heldFatalReportStore: heldReportStore)
        sut.use([SentryEventSourceOrchestrator(heldSource: .watchdogTermination, awaitedSource: .metricKit, holdDuration: 30) { held, awaited, runEnd in
            held.event.tags = ["awaited": awaited.source.rawValue, "watchdog": "\(runEnd.isWatchdogTermination)"]
            return held.event
        }])
        sut.submit(givenWatchdogTerminationReport())

        // -- Act --
        let result = sut.submit(givenDiagnosticReport(runEnd: .memoryTermination))

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).event.tags, ["awaited": "metricKit", "watchdog": "true"])
    }

    func testSubmit_whenSourceIsHeld_shouldScheduleTheDeadlineOfItsOrchestrator() throws {
        // -- Arrange --
        let sut = givenSut(heldFatalReportStore: heldReportStore)
        sut.use([SentryEventSourceOrchestrator(heldSource: .watchdogTermination, awaitedSource: .metricKit, holdDuration: 5) { held, _, _ in held.event }])

        // -- Act --
        sut.submit(givenWatchdogTerminationReport())

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(dispatchQueueWrapper.dispatchAfterInvocations.first).interval, 5)
    }

    func testHasHeldReport_whenAReportIsHeld_shouldReturnTrue() {
        // -- Arrange --
        let sut = givenSut(heldFatalReportStore: heldReportStore)
        XCTAssertFalse(sut.hasHeldReport)
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))

        // -- Act & Assert --
        XCTAssertTrue(sut.hasHeldReport)
    }

    func testHasHeldReport_whenThereIsNoHeldReportStore_shouldReturnFalse() {
        // -- Act & Assert --
        XCTAssertFalse(givenSut(heldFatalReportStore: nil).hasHeldReport)
    }

    // MARK: - Helpers

    private func givenSut(heldFatalReportStore: SentryHeldFatalReportStore?) -> SentryEventSourceCoordinator {
        SentryEventSourceCoordinator(
            downstream: downstream,
            fatalRunRecordStore: nil,
            heldFatalReportStore: heldFatalReportStore,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: dispatchQueueWrapper,
            notificationCenter: TestNSNotificationCenterWrapper()
        )
    }

    private func givenWatchdogTerminationReport() -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: .watchdogTermination,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: false),
            runId: SentryCurrentRun.ID(rawValue: "run-1"),
            event: Event(level: .fatal)
        )
    }

    private func givenDiagnosticReport(runEnd: SentryEventSourceReport.RunEnd) -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [], runEnd: runEnd),
            runId: SentryCurrentRun.ID(rawValue: "run-1"),
            event: Event(level: .error)
        )
    }
}
