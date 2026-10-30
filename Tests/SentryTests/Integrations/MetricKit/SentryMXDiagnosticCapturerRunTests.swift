@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

/// Covers how `SentryMXDiagnosticCapturer` handles MetricKit crashes of recorded runs, see
/// decision 41 in `develop-docs/DECISIONS.md`.
final class SentryMXDiagnosticCapturerRunTests: SentrySDKIntegrationTestsBase {

    private static let currentPid: pid_t = 4_242
    private static let previousPid: pid_t = 1_337

    private var directory: String!
    private var dateProvider: TestCurrentDateProvider!
    private var previousRunScope: TestPreviousRunScope!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = (NSTemporaryDirectory() as NSString).appendingPathComponent("SentryMXDiagnosticCapturerRunTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        dateProvider = TestCurrentDateProvider()
        dateProvider.setDate(date: Date(timeIntervalSince1970: 10_000))
        previousRunScope = TestPreviousRunScope()
    }

    override func setUp() {
        // XCTest calls setUpWithError before setUp, where the base class creates its crash
        // reporter state.
        super.setUp()
        givenSdkWithHub()
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(atPath: directory)
        try super.tearDownWithError()
        // swiftlint:disable:next avoid_clear_test_state - the SDK is started with a hub per test.
        clearTestState()
    }

    // MARK: - Deduplication

    func testCapture_whenCrashOfRunReportedByCrashHandler_shouldDropIt() throws {
        // -- Arrange --
        let runStore = givenRunStore(previousRunCrashed: true)
        let sut = givenSut(runStore: runStore)

        // -- Act --
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        assertNoEventCaptured()
        XCTAssertEqual(runStore.fatalRuns, [], "A second delivery must not match the run again")
    }

    func testCapture_whenCrashOfReportedRunIsDeliveredTwice_shouldCaptureSecondDelivery() throws {
        // -- Arrange --
        let sut = givenSut(runStore: givenRunStore(previousRunCrashed: true))
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Act --
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.exceptions?.first?.type, "MXCrashDiagnostic")
        }
    }

    func testCapture_whenCrashMatchesRunIdOfReportedRun_shouldDropIt() throws {
        // -- Arrange --
        let runStore = givenRunStore(previousRunCrashed: true)
        let runId = try XCTUnwrap(runStore.fatalRuns.first?.runId)
        let sut = givenSut(runStore: runStore)

        // -- Act --
        // The run ID is exact, so the time range doesn't matter.
        sut.capture(try givenDiagnostic(.crash, runIds: [runId], from: 9_000, to: 9_100))

        // -- Assert --
        assertNoEventCaptured()
    }

    func testCapture_whenHangOfRunReportedByCrashHandler_shouldCaptureIt() throws {
        // -- Arrange --
        let runStore = givenRunStore(previousRunCrashed: true)
        let sut = givenSut(runStore: runStore)

        // -- Act --
        sut.capture(try givenDiagnostic(.hang, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.exceptions?.first?.type, "MXHangDiagnostic")
        }
        XCTAssertEqual(runStore.fatalRuns.count, 1, "Only crashes are matched")
    }

    func testCapture_whenCrashOfWatchdogTerminatedRun_shouldCaptureIt() throws {
        // -- Arrange --
        let sut = givenSut(runStore: givenRunStore(previousRunWatchdogTerminated: true))

        // -- Act --
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.exceptions?.first?.type, "MXCrashDiagnostic")
        }
        XCTAssertEqual(previousRunScope.appliedEvents.count, 0)
    }

    func testCapture_whenCrashTimeRangeIsOutsideReportedRun_shouldCaptureIt() throws {
        // -- Arrange --
        // A reused process ID in a later run must not drop that run's crash.
        let sut = givenSut(runStore: givenRunStore(previousRunCrashed: true))

        // -- Act --
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 2_500, to: 2_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.exceptions?.first?.type, "MXCrashDiagnostic")
        }
    }

    func testCapture_whenNoRunStore_shouldCaptureCrash() throws {
        // -- Arrange --
        let sut = givenSut(runStore: nil)

        // -- Act --
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.exceptions?.first?.type, "MXCrashDiagnostic")
        }
    }

    func testDidReceive_whenLegacyCrashPayloadOfReportedRun_shouldMatchByPayloadTimeRange() throws {
        guard #available(iOS 17.0, macOS 14.0, *) else {
            throw XCTSkip("MetricKit reports the process ID on iOS 17 and macOS 14 and later")
        }
        // -- Arrange --
        let runStore = givenRunStore(previousRunCrashed: true)
        let sut = SentryMXManager(metricManager: NoopMXMetricManager(), diagnosticCapturer: givenSut(runStore: runStore))
        let metaData = TestMXMetaData()
        metaData.overrides.pid = Self.previousPid
        let crash = TestMXCrashDiagnostic()
        crash.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        crash.overrides.metaData = metaData
        let payload = TestMXDiagnosticPayload()
        payload.overrides.crashDiagnostics = [crash]
        // The payload starts before the run and only overlaps it through its end.
        payload.overrides.timeStampBegin = Date(timeIntervalSince1970: 500)
        payload.overrides.timeStampEnd = Date(timeIntervalSince1970: 1_500)

        // -- Act --
        sut.didReceive([payload])

        // -- Assert --
        assertNoEventCaptured()
    }

    // MARK: - Previous run scope

    func testCapture_whenUnreportedCrashOfRunDirectlyBefore_shouldApplyPreviousRunScope() throws {
        // -- Arrange --
        // The crash handler didn't report the run, for example after a background crash.
        let sut = givenSut(runStore: givenRunStore())

        // -- Act --
        sut.capture(try givenDiagnostic(.crash, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            let event = try XCTUnwrap(event)
            XCTAssertEqual(event.tags?["previous-run"], "true")
            XCTAssertEqual(previousRunScope.appliedEvents.first?.eventId, event.eventId)
        }
    }

    func testCapture_whenUnreportedCrashOfOlderRun_shouldNotApplyPreviousRunScope() throws {
        // -- Arrange --
        let sut = givenSut(runStore: givenRunStore())

        // -- Act --
        // The SDK only has the scope data of the run directly before the running process.
        sut.capture(try givenDiagnostic(.crash, pid: 999, from: 500, to: 600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.tags?["previous-run"])
        }
        XCTAssertEqual(previousRunScope.appliedEvents.count, 0)
    }

    func testCapture_whenHangOfRunDirectlyBefore_shouldNotApplyPreviousRunScope() throws {
        // -- Arrange --
        let sut = givenSut(runStore: givenRunStore())

        // -- Act --
        sut.capture(try givenDiagnostic(.hang, pid: Self.previousPid, from: 1_500, to: 1_600))

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.tags?["previous-run"])
        }
    }

    // MARK: - Helpers

    /// A run with `previousPid` from 1,000 to 2,000, followed by the running process.
    private func givenRunStore(previousRunCrashed: Bool = false, previousRunWatchdogTerminated: Bool = false) -> SentryMXRunStore {
        let path = (directory as NSString).appendingPathComponent("metrickit-runs.json")
        let previous = SentryMXRunStore(
            path: path,
            currentRun: SentryMXRunStore.Run(runId: UUID(), pid: Self.previousPid, start: Date(timeIntervalSince1970: 1_000)),
            dateProvider: dateProvider
        )
        previous.recordPreviousRun(crashed: false, watchdogTerminated: false)
        let current = SentryMXRunStore(
            path: path,
            currentRun: SentryMXRunStore.Run(runId: UUID(), pid: Self.currentPid, start: Date(timeIntervalSince1970: 2_000)),
            dateProvider: dateProvider
        )
        current.recordPreviousRun(crashed: previousRunCrashed, watchdogTerminated: previousRunWatchdogTerminated)
        return current
    }

    private func givenSut(runStore: SentryMXRunStore?) -> SentryMXDiagnosticCapturer {
        SentryMXDiagnosticCapturer(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: false,
            enabledDiagnostics: SentryMetricKit.DiagnosticReport.all,
            processIdentifier: Self.currentPid,
            processStartDate: Date(timeIntervalSince1970: 2_000),
            runStore: runStore,
            previousRunScope: previousRunScope
        )
    }

    private func givenDiagnostic(
        _ report: SentryMetricKit.DiagnosticReport,
        runIds: [UUID] = [],
        pid: pid_t? = nil,
        from: TimeInterval,
        to: TimeInterval
    ) throws -> SentryMXDiagnostic {
        let callStackTreeJSON = try contentsOfResource("MetricKitCallstacks/per-thread")
        let diagnostic = SentryMXDiagnostic(
            report: report,
            exceptionValue: { "value" },
            timestamp: Date(timeIntervalSince1970: from),
            metadata: SentryMXDiagnostic.Metadata(pid: pid, runIds: runIds, appVersion: "", appBuild: "", osVersion: nil, osBuild: nil),
            callStackTree: { try JSONDecoder().decode(SentryMXCallStackTree.self, from: callStackTreeJSON) },
            rawJSON: { nil },
            rawFilename: "MXDiagnosticPayload.json"
        )
        return diagnostic.with(payloadTimeStampBegin: Date(timeIntervalSince1970: from), end: Date(timeIntervalSince1970: to))
    }
}

private final class NoopMXMetricManager: SentryMXMetricManager {
    func add(_ subscriber: MXMetricManagerSubscriber) {}

    func remove(_ subscriber: MXMetricManagerSubscriber) {}
}

private final class TestPreviousRunScope: SentryMXPreviousRunScopeApplying {
    private(set) var appliedEvents: [Event] = []

    func apply(to event: Event) {
        appliedEvents.append(event)
        event.tags = ["previous-run": "true"]
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
