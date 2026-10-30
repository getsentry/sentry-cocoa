@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if (os(iOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// Covers how watchdog termination events wait for MetricKit, see decision 41 in
/// `develop-docs/DECISIONS.md`.
final class SentryMXWatchdogTerminationHoldTests: XCTestCase {

    private static let previousPid: pid_t = 1_337

    private var directory: String!
    private var dateProvider: TestCurrentDateProvider!
    private var dispatchQueue: TestSentryDispatchQueueWrapper!
    private var notificationCenter: TestNSNotificationCenterWrapper!
    private var capturedEvents: [Event] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = (NSTemporaryDirectory() as NSString).appendingPathComponent("SentryMXWatchdogTerminationHoldTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 10_000))
        dispatchQueue = TestSentryDispatchQueueWrapper()
        notificationCenter = TestNSNotificationCenterWrapper()
        capturedEvents = []
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(atPath: directory)
        try super.tearDownWithError()
    }

    // MARK: - Holding

    func testHold_whenDisabled_shouldNotHoldEvent() {
        // -- Arrange --
        let sut = givenSut(isEnabled: false)

        // -- Act & Assert --
        XCTAssertFalse(sut.hold(givenEvent()))
        XCTAssertEqual(dispatchQueue.dispatchAfterInvocations.count, 0)
    }

    func testHold_whenPreviousRunIsNotRecordedAsWatchdogTermination_shouldNotHoldEvent() {
        // -- Arrange --
        let sut = givenSut(runStore: givenRunStore(previousRunWatchdogTerminated: false))

        // -- Act & Assert --
        XCTAssertFalse(sut.hold(givenEvent()))
    }

    func testHold_whenPreviousRunWasWatchdogTerminated_shouldHoldEventForDuration() throws {
        // -- Arrange --
        let sut = givenSut()

        // -- Act --
        let held = sut.hold(givenEvent())

        // -- Assert --
        XCTAssertTrue(held)
        XCTAssertEqual(capturedEvents.count, 0)
        XCTAssertEqual(try XCTUnwrap(dispatchQueue.dispatchAfterInvocations.first).interval, SentryMXWatchdogTerminationHold.duration)
    }

    func testHold_whenDurationEnds_shouldSendEventUnchanged() throws {
        // -- Arrange --
        let sut = givenSut()
        let event = givenEvent()
        XCTAssertTrue(sut.hold(event))

        // -- Act --
        dispatchQueue.invokeLastDispatchAfter()

        // -- Assert --
        let sent = try XCTUnwrap(capturedEvents.first)
        XCTAssertEqual(capturedEvents.count, 1)
        XCTAssertEqual(sent.eventId, event.eventId)
        XCTAssertEqual(sent.exceptions?.first?.type, "WatchdogTermination")
        XCTAssertEqual(sent.tags, ["screen": "checkout"])
    }

    func testHold_whenAppMovesToBackground_shouldSendEvent() {
        // -- Arrange --
        let sut = givenSut()
        XCTAssertTrue(sut.hold(givenEvent()))

        // -- Act --
        notificationCenter.post(Notification(name: UIApplication.didEnterBackgroundNotification))

        // -- Assert --
        XCTAssertEqual(capturedEvents.count, 1)
    }

    func testHold_whenSentTwice_shouldSendEventOnce() {
        // -- Arrange --
        let sut = givenSut()
        XCTAssertTrue(sut.hold(givenEvent()))

        // -- Act --
        notificationCenter.post(Notification(name: UIApplication.didEnterBackgroundNotification))
        dispatchQueue.invokeLastDispatchAfter()

        // -- Assert --
        XCTAssertEqual(capturedEvents.count, 1)
    }

    func testSendPendingEvent_whenEventWasHeldDuringEarlierLaunch_shouldSendIt() {
        // -- Arrange --
        // The app was closed before the hold ended.
        let runStore = givenRunStore()
        XCTAssertTrue(givenSut(runStore: runStore).hold(givenEvent()))
        let sut = givenSut(runStore: runStore, isEnabled: false)

        // -- Act --
        sut.sendPendingEvent()

        // -- Assert --
        XCTAssertEqual(capturedEvents.count, 1)
    }

    func testSendPendingEvent_whenNothingHeld_shouldNotSend() {
        // -- Act --
        givenSut().sendPendingEvent()

        // -- Assert --
        XCTAssertEqual(capturedEvents.count, 0)
    }

    // MARK: - Taking the event

    func testTakeEvent_whenDiagnosticBelongsToHeldRun_shouldReturnEventOnce() throws {
        // -- Arrange --
        let runStore = givenRunStore()
        let sut = givenSut(runStore: runStore)
        let event = givenEvent()
        XCTAssertTrue(sut.hold(event))

        // -- Act --
        let taken = sut.takeEvent(matching: givenDiagnosticRun(pid: Self.previousPid))

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(taken).eventId, event.eventId)
        XCTAssertEqual(taken?.serializedBreadcrumbs?.count ?? taken?.breadcrumbs?.count, 1)
        XCTAssertNil(sut.takeEvent(matching: givenDiagnosticRun(pid: Self.previousPid)))
        XCTAssertEqual(runStore.fatalRuns, [], "The run is handled")
        dispatchQueue.invokeLastDispatchAfter()
        XCTAssertEqual(capturedEvents.count, 0, "A taken event isn't sent again when the hold ends")
    }

    func testTakeEvent_whenDiagnosticBelongsToOtherRun_shouldKeepEvent() {
        // -- Arrange --
        let sut = givenSut()
        XCTAssertTrue(sut.hold(givenEvent()))

        // -- Act --
        let taken = sut.takeEvent(matching: givenDiagnosticRun(pid: 999))

        // -- Assert --
        XCTAssertNil(taken)
        dispatchQueue.invokeLastDispatchAfter()
        XCTAssertEqual(capturedEvents.count, 1)
    }

    // MARK: - Options

    func testIsEnabled_whenOptionIsDisabled_shouldBeDisabled() {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enabledDiagnosticReports = [.crash]

        // -- Act & Assert --
        XCTAssertFalse(SentryMXWatchdogTerminationHold.isEnabled(for: options))
    }

    func testIsEnabled_whenNoDiagnosticIsEnabled_shouldBeDisabled() {
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enrichWatchdogTerminations = true
        options.experimental.metrickit.enabledDiagnosticReports = []
        #if !SDK_V10
        options.enableMetricKit = false
        #endif // !SDK_V10

        // -- Act & Assert --
        // MetricKit doesn't deliver diagnostics without enabled diagnostic reports.
        XCTAssertFalse(SentryMXWatchdogTerminationHold.isEnabled(for: options))
    }

    func testIsEnabled_whenOptionAndDiagnosticsAreEnabled_shouldBeEnabledOnSupportedVersions() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("MetricKit reports the process ID on iOS 17 and later")
        }
        // -- Arrange --
        let options = Options()
        options.experimental.metrickit.enrichWatchdogTerminations = true
        options.experimental.metrickit.enabledDiagnosticReports = [.hang]

        // -- Act & Assert --
        XCTAssertTrue(SentryMXWatchdogTerminationHold.isEnabled(for: options))
    }

    // MARK: - Helpers

    /// A run with `previousPid` from 1,000 to 2,000, followed by the running process.
    private func givenRunStore(previousRunWatchdogTerminated: Bool = true) -> SentryMXRunStore {
        let path = (directory as NSString).appendingPathComponent("metrickit-runs.json")
        SentryMXRunStore(
            path: path,
            currentRun: SentryMXRunStore.Run(runId: UUID(), pid: Self.previousPid, start: Date(timeIntervalSince1970: 1_000)),
            dateProvider: dateProvider
        ).recordPreviousRun(crashed: false, watchdogTerminated: false)
        let current = SentryMXRunStore(
            path: path,
            currentRun: SentryMXRunStore.Run(runId: UUID(), pid: 4_242, start: Date(timeIntervalSince1970: 2_000)),
            dateProvider: dateProvider
        )
        current.recordPreviousRun(crashed: false, watchdogTerminated: previousRunWatchdogTerminated)
        return current
    }

    private func givenSut(runStore: SentryMXRunStore? = nil, isEnabled: Bool = true) -> SentryMXWatchdogTerminationHold {
        SentryMXWatchdogTerminationHold(
            path: (directory as NSString).appendingPathComponent("metrickit-held-watchdog-termination.json"),
            runStore: runStore ?? givenRunStore(),
            isEnabled: isEnabled,
            dispatchQueue: dispatchQueue,
            notificationCenter: notificationCenter,
            captureFatalEvent: { [weak self] event in self?.capturedEvents.append(event) }
        )
    }

    private func givenEvent() -> Event {
        let event = Event(level: .fatal)
        let exception = Exception(value: SentryWatchdogTerminationConstants.ExceptionValue, type: SentryWatchdogTerminationConstants.ExceptionType)
        let mechanism = Mechanism(type: SentryWatchdogTerminationConstants.MechanismType)
        mechanism.handled = false
        exception.mechanism = mechanism
        event.exceptions = [exception]
        event.tags = ["screen": "checkout"]
        event.serializedBreadcrumbs = [TestData.crumb.serialize()]
        return event
    }

    private func givenDiagnosticRun(pid: pid_t) -> SentryMXDiagnosticRun {
        SentryMXDiagnosticRun(
            runIds: [],
            pid: pid,
            timeRange: DateInterval(start: Date(timeIntervalSince1970: 1_500), end: Date(timeIntervalSince1970: 1_600))
        )
    }
}

#endif // (os(iOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
