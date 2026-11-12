@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

final class SentryEventSourceCoordinatorTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryEventSourceCoordinatorTests.self)

    private var fileManager: SentryFileManager!
    private var dateProvider: TestCurrentDateProvider!
    private var store: SentryFatalRunRecordStore!
    private var heldReportStore: SentryHeldFatalReportStore!
    private var downstream: TestEventSourceSink!
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    private var notificationCenter: TestNSNotificationCenterWrapper!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsn
        dateProvider = TestCurrentDateProvider()
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        store = SentryFatalRunRecordStore(fileManager: fileManager, dateProvider: dateProvider)
        heldReportStore = SentryHeldFatalReportStore(fileManager: fileManager)
        downstream = TestEventSourceSink()
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        dispatchQueueWrapper.dispatchAfterExecutesBlock = false
        notificationCenter = TestNSNotificationCenterWrapper()
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
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil)))

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
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil))) {
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
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil)))

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
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil)))

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
        sut.submit(givenDiagnosticReport(runId: nil, runEnd: .crash(terminationReason: nil)))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenCrashDiagnosticDescribesUnrecordedRun_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))
        downstream.submittedReports.removeAll()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-2", runEnd: .crash(terminationReason: nil)))

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
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil)))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenThereIsNoStore_shouldForwardEveryReport() {
        // -- Arrange --
        let sut = givenSut(fatalRunRecordStore: nil, heldFatalReportStore: nil)
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil)))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 2)
    }

    // MARK: - Holding fatal reports

    func testSubmit_whenSourceIsHeld_shouldStoreFatalReportInsteadOfForwardingIt() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        let event = Event(level: .fatal)
        event.tags = ["previous": "run"]

        // -- Act --
        let result = sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: event))

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 0)
        let held = try XCTUnwrap(heldReportStore.read())
        XCTAssertEqual(held.runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertEqual(held.source, .watchdogTermination)
        XCTAssertEqual(held.event.tags, ["previous": "run"])
        XCTAssertNil(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1")), "The run is recorded when the held report is sent")
    }

    func testSubmit_whenSourceIsHeld_shouldTakeCrashedSessionOfHeldRun() throws {
        // -- Arrange --
        let session = givenCrashedSession()
        fileManager.storeCrashedSession(session)
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).session?.sessionId, session.sessionId)
        XCTAssertNil(fileManager.readCrashedSession(), "No other fatal event may be sent with the session of the held run")
    }

    func testSendHeldReport_whenCrashedSessionWasReplacedWhileHeld_shouldSendReportWithSessionOfItsRun() throws {
        // -- Arrange --
        let sessionOfHeldRun = givenCrashedSession()
        fileManager.storeCrashedSession(sessionOfHeldRun)
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))
        // The app crashed while the report was held, and the next launch stored the crashed
        // session of that run for the crash handler's event.
        let sessionOfCrashedRun = givenCrashedSession()
        fileManager.storeCrashedSession(sessionOfCrashedRun)

        // -- Act --
        sut.sendHeldReport(because: "a previous run left it behind")

        // -- Assert --
        let sent = try XCTUnwrap(downstream.submittedReports.first)
        guard case let .carried(carried) = sent.crashedSession else {
            return XCTFail("Expected the held report to carry its session")
        }
        XCTAssertEqual(carried?.sessionId, sessionOfHeldRun.sessionId)
        XCTAssertEqual(fileManager.readCrashedSession()?.sessionId, sessionOfCrashedRun.sessionId)
    }

    func testSubmit_whenDiagnosticEnrichesHeldReport_shouldSendItWithSessionOfHeldRun() throws {
        // -- Arrange --
        let session = givenCrashedSession()
        fileManager.storeCrashedSession(session)
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: givenWatchdogTerminationEvent()))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .memoryTermination, event: givenMetricKitCrashEvent()))

        // -- Assert --
        let sent = try XCTUnwrap(downstream.submittedReports.first)
        guard case let .carried(carried) = sent.crashedSession else {
            return XCTFail("Expected the enriched report to carry its session")
        }
        XCTAssertEqual(carried?.sessionId, session.sessionId)
    }

    func testSubmit_whenSourceIsHeld_shouldScheduleTheDeadline() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(dispatchQueueWrapper.dispatchAfterInvocations.count, 1)
        XCTAssertEqual(try XCTUnwrap(dispatchQueueWrapper.dispatchAfterInvocations.first).interval, 30)
    }

    func testSubmit_whenHeldReportHasNoRunId_shouldForwardIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: nil))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertNil(heldReportStore.read())
    }

    func testSubmit_whenAnotherSourceIsHeld_shouldForwardFatalReport() {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertNil(heldReportStore.read())
    }

    func testSubmit_whenHoldingStopped_shouldForwardFatalReport() {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.stopHolding(fatalReportsOf: .watchdogTermination)

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertNil(heldReportStore.read())
    }

    func testSubmit_whenThereIsNoHeldReportStore_shouldForwardFatalReportOfHeldSource() {
        // -- Arrange --
        let sut = givenSut(fatalRunRecordStore: store, heldFatalReportStore: nil)
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
    }

    func testSubmit_whenSourceWithdrawsHeldReport_shouldNotStoreIt() {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        let result = sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1")) { false }

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertNil(heldReportStore.read())
        XCTAssertEqual(dispatchQueueWrapper.dispatchAfterInvocations.count, 0)
    }

    func testSubmit_whenDownstreamIsUnavailable_shouldStillHoldFatalReport() {
        // -- Arrange --
        downstream.isAvailable = false
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Act --
        let result = sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertNotNil(heldReportStore.read())
    }

    func testSubmit_whenAReportIsAlreadyHeld_shouldSendItBeforeHoldingTheNewOne() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Act --
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-2"))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-2"))
    }

    // MARK: - Sending held reports

    func testDeadline_whenItPasses_shouldSendHeldReportUnchangedAndRecordRun() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        let event = Event(level: .fatal)
        event.tags = ["previous": "run"]
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: event))

        // -- Act --
        dispatchQueueWrapper.invokeLastDispatchAfter()

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        let sent = try XCTUnwrap(downstream.submittedReports.first)
        XCTAssertEqual(sent.source, .watchdogTermination)
        XCTAssertEqual(sent.runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertEqual(sent.event.tags, ["previous": "run"])
        XCTAssertEqual(sent.event.breadcrumbs?.count, 0, "The current scope must not add its breadcrumbs")
        guard case .fatal(let attachmentPaths, let isRetainedOnFailure) = sent.kind else {
            return XCTFail("Expected a fatal report")
        }
        XCTAssertEqual(attachmentPaths, [])
        XCTAssertFalse(isRetainedOnFailure)
        XCTAssertNil(heldReportStore.read())
        XCTAssertEqual(try XCTUnwrap(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1"))).reportedBy, .watchdogTermination)
    }

    func testDeadline_whenHeldReportBelongsToAnotherRun_shouldNotSendIt() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))
        let deadlineOfRun1 = try XCTUnwrap(dispatchQueueWrapper.dispatchAfterInvocations.first).block
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-2"))
        downstream.submittedReports.removeAll()

        // -- Act --
        deadlineOfRun1()

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 0)
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-2"))
    }

    func testDeadline_whenDownstreamIsUnavailable_shouldKeepHeldReport() {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))
        downstream.isAvailable = false

        // -- Act --
        dispatchQueueWrapper.invokeLastDispatchAfter()

        // -- Assert --
        XCTAssertNotNil(heldReportStore.read())
        XCTAssertNil(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1")))
    }

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func testBackground_whenAppMovesToBackground_shouldSendHeldReport() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Act --
        notificationCenter.post(Notification(name: UIApplication.didEnterBackgroundNotification))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertNil(heldReportStore.read())
    }

    func testHold_whenCalledTwice_shouldObserveBackgroundOnce() {
        // -- Arrange --
        let sut = givenSut()

        // -- Act --
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.hold(fatalReportsOf: .watchdogTermination, for: 60)

        // -- Assert --
        XCTAssertEqual(notificationCenter.addObserverWithBlockInvocations.count, 1)
    }
    #endif

    func testHold_whenAPreviousRunLeftAHeldReport_shouldSendIt() throws {
        // -- Arrange --
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))
        let sut = givenSut()

        // -- Act --
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).runId, SentryCurrentRun.ID(rawValue: "run-1"))
        XCTAssertNil(heldReportStore.read())
        XCTAssertEqual(try XCTUnwrap(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1"))).reportedBy, .watchdogTermination)
    }

    func testSubmit_whenAPreviousRunLeftAHeldReportAndNothingIsHeld_shouldSendItBeforeAFatalReport() throws {
        // -- Arrange --
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))
        let sut = givenSut()

        // -- Act --
        sut.submit(givenFatalReport(source: .crashHandler, runId: "run-2"))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.map(\.runId?.rawValue), ["run-1", "run-2"])
        XCTAssertNil(heldReportStore.read())
    }

    func testSubmit_whenAPreviousRunLeftAHeldReport_shouldNotSendItBeforeADiagnostic() throws {
        // -- Arrange --
        heldReportStore.store(SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: "run-1"), source: .watchdogTermination, event: Event(level: .fatal)))
        let sut = givenSut()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-2", runEnd: nil))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.map(\.runId?.rawValue), ["run-2"])
        XCTAssertNotNil(heldReportStore.read())
    }

    // MARK: - Enriching held reports

    func testSubmit_whenWatchdogCrashDiagnosticDescribesHeldRun_shouldSendHeldReportWithItsStackTrace() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: givenWatchdogTerminationEvent()))
        let diagnostic = givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: "Namespace SPRINGBOARD, Code 0x8badf00d"), event: givenMetricKitCrashEvent())

        // -- Act --
        let result = sut.submit(diagnostic)

        // -- Assert --
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(downstream.submittedReports.count, 1)
        let sent = try XCTUnwrap(downstream.submittedReports.first)
        XCTAssertEqual(sent.source, .watchdogTermination)
        XCTAssertEqual(sent.runId, SentryCurrentRun.ID(rawValue: "run-1"))
        guard case .fatal = sent.kind else {
            return XCTFail("Expected a fatal report")
        }
        XCTAssertEqual(sent.event.tags, ["previous": "run"])
        let exception = try XCTUnwrap(sent.event.exceptions?.first)
        XCTAssertEqual(exception.type, SentryWatchdogTerminationConstants.ExceptionType)
        XCTAssertEqual(exception.mechanism?.type, SentryWatchdogTerminationConstants.MechanismType)
        XCTAssertEqual(exception.mechanism?.data?["termination_reason"] as? String, "Namespace SPRINGBOARD, Code 0x8badf00d")
        XCTAssertEqual(exception.stacktrace?.frames.count, 1)
        XCTAssertEqual(sent.event.threads?.count, 1)
        XCTAssertEqual(sent.event.debugMeta?.count, 1)
        XCTAssertNil(heldReportStore.read())
        XCTAssertEqual(try XCTUnwrap(store.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1"))).reportedBy, .watchdogTermination)
    }

    func testSubmit_whenOtherCrashDiagnosticDescribesHeldRun_shouldSendHeldReportAsThatCrash() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: givenWatchdogTerminationEvent()))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil), event: givenMetricKitCrashEvent()))

        // -- Assert --
        let sent = try XCTUnwrap(downstream.submittedReports.first)
        XCTAssertEqual(sent.source, .watchdogTermination)
        XCTAssertEqual(sent.event.tags, ["previous": "run"])
        XCTAssertEqual(sent.event.level, .fatal)
        let exception = try XCTUnwrap(sent.event.exceptions?.first)
        XCTAssertEqual(exception.type, "MXCrashDiagnostic")
        XCTAssertEqual(exception.stacktrace?.frames.count, 1)
        XCTAssertEqual(sent.event.threads?.count, 1)
    }

    func testSubmit_whenMemoryDiagnosticDescribesHeldRun_shouldSendHeldReportAsWatchdogTermination() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: givenWatchdogTerminationEvent()))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .memoryTermination, event: givenMetricKitCrashEvent(value: "The app or extension exceeded its memory limit")))

        // -- Assert --
        let exception = try XCTUnwrap(downstream.submittedReports.first?.event.exceptions?.first)
        XCTAssertEqual(exception.type, SentryWatchdogTerminationConstants.ExceptionType)
        XCTAssertEqual(exception.mechanism?.data?["termination_reason"] as? String, "The app or extension exceeded its memory limit")
        XCTAssertEqual(exception.stacktrace?.frames.count, 1)
    }

    func testSubmit_whenDiagnosticDescribesHeldRunAndDownstreamIsUnavailable_shouldKeepEnrichedReportHeld() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1", event: givenWatchdogTerminationEvent()))
        downstream.isAvailable = false

        // -- Act --
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: "0x8badf00d"), event: givenMetricKitCrashEvent()))
        downstream.isAvailable = true
        dispatchQueueWrapper.invokeLastDispatchAfter()

        // -- Assert --
        XCTAssertEqual(result, .accepted, "The diagnostic is part of the held report now")
        XCTAssertEqual(downstream.submittedReports.count, 1)
        let exception = try XCTUnwrap(downstream.submittedReports.first?.event.exceptions?.first)
        XCTAssertEqual(exception.mechanism?.data?["termination_reason"] as? String, "0x8badf00d")
        XCTAssertNil(heldReportStore.read())
    }

    func testSubmit_whenDiagnosticDescribesAnotherRunThanTheHeldOne_shouldForwardItAndKeepHolding() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-2", runEnd: .crash(terminationReason: nil)))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).source, .metricKit)
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testSubmit_whenDiagnosticOfHeldRunDoesNotEndIt_shouldForwardItAndKeepHolding() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: nil))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).source, .metricKit)
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testSubmit_whenDiagnosticOfHeldRunIsWithdrawn_shouldKeepHolding() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))

        // -- Act --
        let result = sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: nil))) { false }

        // -- Assert --
        XCTAssertEqual(result, .withdrawn)
        XCTAssertEqual(downstream.submittedReports.count, 0)
        XCTAssertEqual(try XCTUnwrap(heldReportStore.read()).runId, SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testSubmit_whenDiagnosticArrivesAfterHeldReportWasSent_shouldForwardItAsItsOwnEvent() throws {
        // -- Arrange --
        let sut = givenSut()
        sut.hold(fatalReportsOf: .watchdogTermination, for: 30)
        sut.submit(givenFatalReport(source: .watchdogTermination, runId: "run-1"))
        dispatchQueueWrapper.invokeLastDispatchAfter()
        downstream.submittedReports.removeAll()

        // -- Act --
        sut.submit(givenDiagnosticReport(runId: "run-1", runEnd: .crash(terminationReason: "0x8badf00d")))

        // -- Assert --
        XCTAssertEqual(downstream.submittedReports.count, 1)
        XCTAssertEqual(try XCTUnwrap(downstream.submittedReports.first).source, .metricKit)
    }

    // MARK: - Helpers

    private func givenSut() -> SentryEventSourceCoordinator {
        givenSut(fatalRunRecordStore: store, heldFatalReportStore: heldReportStore)
    }

    private func givenSut(fatalRunRecordStore: SentryFatalRunRecordStore?, heldFatalReportStore: SentryHeldFatalReportStore?) -> SentryEventSourceCoordinator {
        SentryEventSourceCoordinator(
            downstream: downstream,
            fatalRunRecordStore: fatalRunRecordStore,
            heldFatalReportStore: heldFatalReportStore,
            dateProvider: dateProvider,
            dispatchQueueWrapper: dispatchQueueWrapper,
            notificationCenter: notificationCenter
        )
    }

    private func givenCrashedSession() -> SentrySession {
        let session = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        session.endCrashed(withTimestamp: dateProvider.date())
        return session
    }

    private func givenWatchdogTerminationEvent() -> Event {
        let event = Event(level: .fatal)
        event.tags = ["previous": "run"]
        let exception = Exception(value: SentryWatchdogTerminationConstants.ExceptionValue, type: SentryWatchdogTerminationConstants.ExceptionType)
        let mechanism = Mechanism(type: SentryWatchdogTerminationConstants.MechanismType)
        mechanism.handled = false
        exception.mechanism = mechanism
        event.exceptions = [exception]
        return event
    }

    private func givenMetricKitCrashEvent(value: String = "MachException Type:nil Code:nil Signal:9") -> Event {
        let event = Event(level: .error)
        let thread = SentryThread(threadId: 1)
        thread.crashed = true
        let frame = Frame()
        frame.instructionAddress = "0x0000000100001000"
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        let exception = Exception(value: value, type: "MXCrashDiagnostic")
        exception.mechanism = Mechanism(type: "MXCrashDiagnostic")
        exception.stacktrace = thread.stacktrace
        exception.threadId = thread.threadId
        event.exceptions = [exception]
        event.threads = [thread]
        event.debugMeta = [DebugMeta()]
        return event
    }

    private func givenFatalReport(source: SentryEventSource, runId: String?, event: Event = Event(level: .fatal)) -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: source,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: source == .crashHandler),
            runId: runId.map { SentryCurrentRun.ID(rawValue: $0) },
            event: event
        )
    }

    private func givenDiagnosticReport(runId: String?, runEnd: SentryEventSourceReport.RunEnd?, event: Event = Event(level: .error)) -> SentryEventSourceReport {
        SentryEventSourceReport(
            source: .metricKit,
            kind: .diagnostic(attachments: [], runEnd: runEnd),
            runId: runId.map { SentryCurrentRun.ID(rawValue: $0) },
            event: event
        )
    }
}
