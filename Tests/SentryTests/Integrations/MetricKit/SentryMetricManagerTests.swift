@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

#if (os(iOS) || os(macOS) || os(visionOS)) && compiler(>=6.4)
import MetricKit

final class SentryMetricManagerTests: SentrySDKIntegrationTestsBase {

    private static let timestamp = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let currentPid: pid_t = 4_242
    private static let previousProcessPid: pid_t = 1_337

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else {
            throw XCTSkip("MetricManager requires iOS 27, macOS 27 or visionOS 27")
        }
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - the SDK is started with a hub per test.
        clearTestState()
    }

    // MARK: - Same events as the legacy API

    func testProcess_whenHangReport_shouldCaptureSameEventAsLegacyDiagnostic() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        let legacyDiagnostic = TestMXHangDiagnostic()
        legacyDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let legacyPayload = TestMXDiagnosticPayload()
        legacyPayload.overrides.hangDiagnostic = [legacyDiagnostic]
        let report = try givenReport(result: "hangDiagnostic", diagnostic: [
            "callStackTree": try callStackTree(fromLegacyResource: "MetricKitCallstacks/per-thread"),
            "hangDuration": encoded(legacyDiagnostic.hangDuration)
        ])

        // -- Act & Assert --
        try assertSameEvent(legacyPayload: legacyPayload, report: report, exceptionType: "MXHangDiagnostic")
    }

    func testProcess_whenCrashReport_shouldCaptureSameEventAsLegacyDiagnostic() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        let legacyDiagnostic = TestMXCrashDiagnostic()
        legacyDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        legacyDiagnostic.overrides.exceptionType = 1
        legacyDiagnostic.overrides.exceptionCode = 0
        legacyDiagnostic.overrides.signal = 11
        let legacyPayload = TestMXDiagnosticPayload()
        legacyPayload.overrides.crashDiagnostics = [legacyDiagnostic]
        let report = try givenReport(result: "crashDiagnostic", diagnostic: [
            "callStackTree": try callStackTree(fromLegacyResource: "MetricKitCallstacks/per-thread"),
            "exceptionType": 1,
            "exceptionCode": 0,
            "signal": 11
        ])

        // -- Act & Assert --
        try assertSameEvent(legacyPayload: legacyPayload, report: report, exceptionType: "MXCrashDiagnostic")
    }

    func testProcess_whenCPUExceptionReport_shouldCaptureSameEventAsLegacyDiagnostic() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        let legacyDiagnostic = TestMXCPUExceptionDiagnostic()
        legacyDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        let legacyPayload = TestMXDiagnosticPayload()
        legacyPayload.overrides.cpuDiagnostic = [legacyDiagnostic]
        let report = try givenReport(result: "cpuExceptionDiagnostic", diagnostic: [
            "callStackTree": try callStackTree(fromLegacyResource: "MetricKitCallstacks/not-per-thread"),
            "totalCPUTime": encoded(legacyDiagnostic.totalCPUTime),
            "totalSampledTime": encoded(legacyDiagnostic.totalSampledTime)
        ])

        // -- Act & Assert --
        try assertSameEvent(legacyPayload: legacyPayload, report: report, exceptionType: "MXCPUException")
    }

    func testProcess_whenDiskWriteExceptionReport_shouldCaptureSameEventAsLegacyDiagnostic() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        let legacyDiagnostic = TestMXDiskWriteExceptionDiagnostic()
        legacyDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        let legacyPayload = TestMXDiagnosticPayload()
        legacyPayload.overrides.diskWriteDiagnostic = [legacyDiagnostic]
        let report = try givenReport(result: "diskWriteExceptionDiagnostic", diagnostic: [
            "callStackTree": try callStackTree(fromLegacyResource: "MetricKitCallstacks/not-per-thread"),
            "totalBytesWritten": encoded(legacyDiagnostic.totalWritesCaused)
        ])

        // -- Act & Assert --
        try assertSameEvent(legacyPayload: legacyPayload, report: report, exceptionType: "MXDiskWriteException")
    }

    #if os(iOS)
    func testProcess_whenAppLaunchReport_shouldCaptureSameEventAsLegacyDiagnostic() throws {
        guard #available(iOS 27.0, *) else { return }
        // -- Arrange --
        let legacyDiagnostic = TestMXAppLaunchDiagnostic()
        legacyDiagnostic.overrides.callStackTree.overrides.jsonRepresentation = try contentsOfResource("MetricKitCallstacks/per-thread")
        let legacyPayload = TestMXDiagnosticPayload()
        legacyPayload.overrides.appLaunchDiagnostics = [legacyDiagnostic]
        let report = try givenReport(result: "appLaunchDiagnostic", diagnostic: [
            "callStackTree": try callStackTree(fromLegacyResource: "MetricKitCallstacks/per-thread"),
            "launchDuration": encoded(legacyDiagnostic.launchDuration)
        ])

        // -- Act & Assert --
        try assertSameEvent(legacyPayload: legacyPayload, report: report, exceptionType: "MXAppLaunchDiagnostic")
    }
    #endif // os(iOS)

    func testProcess_whenReportIsNotEnabled_shouldNotCaptureEvent() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let sut = givenSut(enabledDiagnostics: [.crash])
        let report = try givenHangReport()

        // -- Act --
        sut.process(diagnosticReport: report)

        // -- Assert --
        assertNothingCaptured()
    }

    // MARK: - Call stack trees

    func testProcess_whenFrameHasNoAddress_shouldNotCaptureEvent() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let sut = givenSut(enabledDiagnostics: [.hang])
        let report = try givenHangReport(callStackTree: Self.callStackTreeWithFrameWithoutAddress)

        // -- Act --
        sut.process(diagnosticReport: report)

        // -- Assert --
        assertNothingCaptured()
    }

    func testProcess_whenFrameHasNoAddressAndRawPayloadEnabled_shouldAttachEncodedReport() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let sut = givenSut(enabledDiagnostics: [.hang], attachDiagnosticAsAttachment: true)
        let report = try givenHangReport(callStackTree: Self.callStackTreeWithFrameWithoutAddress)

        // -- Act --
        sut.process(diagnosticReport: report)

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNil(event?.exceptions?.first?.stacktrace)
        }
        let attachment = try XCTUnwrap(capturedHintAttachments().first { $0.filename == "DiagnosticReport.json" })
        // JSONEncoder doesn't keep the key order stable, so the decoded JSON is compared.
        let attachmentJSON = try JSONSerialization.jsonObject(with: XCTUnwrap(attachment.data)) as? NSDictionary
        let reportJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? NSDictionary
        XCTAssertNotNil(reportJSON)
        XCTAssertEqual(attachmentJSON, reportJSON)
    }

    // MARK: - Metadata

    func testProcess_whenReportFromPreviousProcess_shouldApplyEnvironmentVersions() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let sut = givenSut(enabledDiagnostics: [.hang], releaseName: "io.sentry.app@2.0.0+20")
        let report = try givenHangReport(
            pid: Self.previousProcessPid,
            appVersion: "1.0.0",
            appBuild: "10",
            osVersion: ["platform": "iOS", "number": "27.0", "buildNumber": "24A100"]
        )

        // -- Act --
        sut.process(diagnosticReport: report)

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            let event = try XCTUnwrap(event)
            XCTAssertEqual(event.isFromPreviousProcess, true)
            XCTAssertEqual(event.releaseName, "io.sentry.app@1.0.0+10")
            XCTAssertEqual(event.dist, "10")
            let appContext = try XCTUnwrap(event.context?["app"])
            XCTAssertEqual(appContext["app_version"] as? String, "1.0.0")
            XCTAssertEqual(appContext["app_build"] as? String, "10")
            let osContext = try XCTUnwrap(event.context?["os"])
            XCTAssertEqual(osContext["version"] as? String, "27.0")
            XCTAssertEqual(osContext["build"] as? String, "24A100")
        }
    }

    func testProcess_whenReportFromRunningProcess_shouldKeepEventInCurrentAppRun() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let sut = givenSut(enabledDiagnostics: [.hang], releaseName: "io.sentry.app@2.0.0+20")
        let report = try givenHangReport(pid: Self.currentPid, appVersion: "1.0.0", appBuild: "10")

        // -- Act --
        sut.process(diagnosticReport: report)

        // -- Assert --
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(event?.isFromPreviousProcess, false)
            XCTAssertNil(event?.releaseName)
            XCTAssertNil(event?.dist)
        }
    }

    // MARK: - Receiving reports

    func testReceiveReports_shouldCaptureReportsFromMetricManager() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let source = TestDiagnosticReportSource()
        let sut = givenSut(enabledDiagnostics: [.hang], source: source)
        let captured = expectation(for: NSPredicate { _, _ in client.captureEventWithScopeInvocations.count == 1 }, evaluatedWith: nil)

        // -- Act --
        sut.receiveReports()
        source.continuation.yield(try givenHangReport())

        // -- Assert --
        wait(for: [captured], timeout: 5)
    }

    func testPauseReports_shouldStopIteratingMetricManagerReports() throws {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else { return }
        // -- Arrange --
        givenSdkWithHub()
        let source = TestDiagnosticReportSource()
        let terminated = expectation(description: "The report sequence is terminated")
        source.continuation.onTermination = { _ in terminated.fulfill() }
        let sut = givenSut(enabledDiagnostics: [.hang], source: source)
        sut.receiveReports()

        // -- Act --
        sut.pauseReports()

        // -- Assert --
        wait(for: [terminated], timeout: 5)
    }

    // MARK: - Helpers

    private func givenDiagnosticCapturer(
        enabledDiagnostics: Set<SentryMXManager.Diagnostic>,
        attachDiagnosticAsAttachment: Bool = false,
        releaseName: String? = nil
    ) -> SentryMXDiagnosticCapturer {
        SentryMXDiagnosticCapturer(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            attachDiagnosticAsAttachment: attachDiagnosticAsAttachment,
            enabledDiagnostics: enabledDiagnostics,
            releaseName: releaseName,
            bundleInfo: [
                "CFBundleIdentifier": "io.sentry.app",
                "CFBundleShortVersionString": "2.0.0",
                "CFBundleVersion": "20"
            ],
            processIdentifier: Self.currentPid,
            processStartDate: .distantPast
        )
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    private func givenSut(
        enabledDiagnostics: Set<SentryMXManager.Diagnostic>,
        attachDiagnosticAsAttachment: Bool = false,
        releaseName: String? = nil,
        source: SentryDiagnosticReportSource = TestDiagnosticReportSource()
    ) -> SentryMetricManager {
        SentryMetricManager(
            source: source,
            diagnosticCapturer: givenDiagnosticCapturer(
                enabledDiagnostics: enabledDiagnostics,
                attachDiagnosticAsAttachment: attachDiagnosticAsAttachment,
                releaseName: releaseName
            )
        )
    }

    /// Captures the legacy payload and the report with the same capturer and asserts that both
    /// produce the same event.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    private func assertSameEvent(legacyPayload: TestMXDiagnosticPayload, report: MetricKit.DiagnosticReport, exceptionType: String) throws {
        givenSdkWithHub()
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let diagnosticCapturer = givenDiagnosticCapturer(enabledDiagnostics: SentryMXManager.Diagnostic.all)
        let legacyManager = SentryMXManager(metricManager: TestMXMetricManager(), diagnosticCapturer: diagnosticCapturer)
        let sut = SentryMetricManager(source: TestDiagnosticReportSource(), diagnosticCapturer: diagnosticCapturer)
        legacyPayload.overrides.timeStampBegin = Self.timestamp

        legacyManager.didReceive([legacyPayload])
        sut.process(diagnosticReport: report)

        let events = client.captureEventWithScopeInvocations.invocations.map(\.event)
        XCTAssertEqual(events.count, 2)
        let legacyEvent = try XCTUnwrap(events.first)
        let event = try XCTUnwrap(events.last)
        XCTAssertEqual(event.exceptions?.first?.type, exceptionType)
        XCTAssertFalse(try XCTUnwrap(event.threads).isEmpty)
        XCTAssertEqual(Self.comparableSerialization(of: event), Self.comparableSerialization(of: legacyEvent))
    }

    private static func comparableSerialization(of event: Event) -> NSDictionary {
        var serialized = event.serialize()
        serialized.removeValue(forKey: "event_id")
        return serialized as NSDictionary
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    private func givenHangReport(
        callStackTree: [String: Any]? = nil,
        pid: pid_t? = nil,
        appVersion: String = "",
        appBuild: String = "",
        osVersion: [String: Any] = ["platform": "", "number": "", "buildNumber": ""]
    ) throws -> MetricKit.DiagnosticReport {
        try givenReport(
            result: "hangDiagnostic",
            diagnostic: [
                "callStackTree": try callStackTree ?? self.callStackTree(fromLegacyResource: "MetricKitCallstacks/not-per-thread-only-one-frame"),
                "hangDuration": encoded(Measurement(value: 6.6, unit: UnitDuration.seconds))
            ],
            pid: pid,
            appVersion: appVersion,
            appBuild: appBuild,
            osVersion: osVersion
        )
    }

    /// `DiagnosticReport` has no public initializer, so reports are decoded from the JSON format
    /// of its `Codable` conformance.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    private func givenReport(
        result: String,
        diagnostic: [String: Any],
        pid: pid_t? = nil,
        appVersion: String = "",
        appBuild: String = "",
        osVersion: [String: Any] = ["platform": "", "number": "", "buildNumber": ""]
    ) throws -> MetricKit.DiagnosticReport {
        var environment: [String: Any] = [
            "regionFormat": "US",
            "osVersion": osVersion,
            "deviceType": "iPhone18,1",
            "platformArchitecture": "arm64e",
            "lowPowerModeEnabled": false,
            "isTestFlightApp": false,
            "applicationVersion": appVersion,
            "applicationBuildVersion": appBuild,
            "bundleIdentifier": "io.sentry.app",
            "signpostData": [],
            "states": []
        ]
        if let pid {
            environment["pid"] = pid
        }
        let report: [String: Any] = [
            "timeRange": [
                "begin": Self.timestamp.timeIntervalSinceReferenceDate,
                "end": Self.timestamp.addingTimeInterval(60).timeIntervalSinceReferenceDate
            ],
            "environment": environment,
            // The result's case is flattened into the report.
            result: diagnostic
        ]
        let data = try JSONSerialization.data(withJSONObject: report)
        return try JSONDecoder().decode(MetricKit.DiagnosticReport.self, from: data)
    }

    /// MetricKit encodes a measurement's unit by its symbol.
    private func encoded<UnitType: Dimension>(_ measurement: Measurement<UnitType>) -> [String: Any] {
        ["value": measurement.value, "unit": measurement.unit.symbol]
    }

    /// Converts a legacy `MXCallStackTree` JSON representation into the JSON format of
    /// `CallStackTree`.
    private func callStackTree(fromLegacyResource resource: String) throws -> [String: Any] {
        let legacyTree = try XCTUnwrap(JSONSerialization.jsonObject(with: contentsOfResource(resource)) as? [String: Any])
        var binaryInfo: [String: String] = [:]

        func frame(fromLegacy legacyFrame: [String: Any]) -> [String: Any] {
            var converted = legacyFrame
            converted.removeValue(forKey: "binaryName")
            if let uuid = legacyFrame["binaryUUID"] as? String, let name = legacyFrame["binaryName"] as? String {
                binaryInfo[uuid] = name
            }
            let legacySubFrames = legacyFrame["subFrames"] as? [[String: Any]] ?? []
            converted["subFrames"] = legacySubFrames.map { frame(fromLegacy: $0) }
            return converted
        }

        let legacyCallStacks = try XCTUnwrap(legacyTree["callStacks"] as? [[String: Any]])
        let threads: [[String: Any]] = legacyCallStacks.map { callStack in
            var thread: [String: Any] = [
                "rootFrames": (callStack["callStackRootFrames"] as? [[String: Any]] ?? []).map { frame(fromLegacy: $0) }
            ]
            thread["threadAttributed"] = callStack["threadAttributed"]
            return thread
        }
        return [
            "callStackThreads": threads,
            "callStackPerThread": try XCTUnwrap(legacyTree["callStackPerThread"]),
            "binaryInfo": binaryInfo.map { ["uuid": $0.key, "name": $0.value] }
        ]
    }

    private static let callStackTreeWithFrameWithoutAddress: [String: Any] = [
        "callStackThreads": [
            ["rootFrames": [["binaryUUID": "810E428A-F26D-37BB-BB0F-609CBB4718C7", "offsetIntoBinaryTextSegment": 6_659, "subFrames": []]]]
        ],
        "callStackPerThread": false,
        "binaryInfo": []
    ]

    private func capturedHintAttachments() throws -> [Attachment] {
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let capture = try XCTUnwrap(client.captureEventWithScopeAndHintInvocations.first)
        return capture.hint?.attachments ?? []
    }

    private func assertNothingCaptured() {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 0)
    }
}

private final class TestMXMetricManager: SentryMXMetricManager {
    func add(_ subscriber: MXMetricManagerSubscriber) {}

    func remove(_ subscriber: MXMetricManagerSubscriber) {}
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
private final class TestDiagnosticReportSource: SentryDiagnosticReportSource {
    let reports: AsyncStream<MetricKit.DiagnosticReport>
    let continuation: AsyncStream<MetricKit.DiagnosticReport>.Continuation

    init() {
        (reports, continuation) = AsyncStream.makeStream()
    }

    func makeDiagnosticReports() -> any AsyncSequence<MetricKit.DiagnosticReport, Never> {
        reports
    }
}

#endif // (os(iOS) || os(macOS) || os(visionOS)) && compiler(>=6.4)
