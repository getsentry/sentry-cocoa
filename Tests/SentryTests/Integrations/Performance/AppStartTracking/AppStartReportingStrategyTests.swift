@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class AppStartReportingStrategyTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // The integration tests modify SentryDependencyContainer global state
        // (debugImageProvider, framesTracker, hub), so we need the full cleanup.
        clearTestState()
    }

    private func createMeasurement(type: SentryAppStartType, duration: TimeInterval = 0.5) -> SentryAppStartMeasurement {
        let dateProvider = TestCurrentDateProvider()
        let appStart = dateProvider.date()
        return SentryAppStartMeasurement(
            type: type,
            isPreWarmed: false,
            appStartTimestamp: appStart,
            runtimeInitSystemTimestamp: dateProvider.systemTime(),
            duration: duration,
            runtimeInitTimestamp: appStart.addingTimeInterval(0.05),
            moduleInitializationTimestamp: appStart.addingTimeInterval(0.1),
            sdkStartTimestamp: appStart.addingTimeInterval(0.15),
            didFinishLaunchingTimestamp: appStart.addingTimeInterval(0.3)
        )
    }

    private func createHub() -> TestHub {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "AppStartReportingStrategyTests")
        options.tracesSampleRate = 1
        let client = TestClient(options: options)
        return TestHub(client: client, andScope: Scope())
    }

    // MARK: - AttachToTransactionStrategy

    func testAttach_SetsMeasurementOnGlobalStatic() throws {
        let measurement = createMeasurement(type: .cold)

        AttachToTransactionStrategy().report(measurement)

        let stored = try XCTUnwrap(SentrySDKInternal.getAppStartMeasurement())
        XCTAssertEqual(stored.type, .cold)
        XCTAssertEqual(stored.duration, measurement.duration)
    }

    func testAttach_WarmStart_SetsMeasurementOnGlobalStatic() throws {
        let measurement = createMeasurement(type: .warm)

        AttachToTransactionStrategy().report(measurement)

        let stored = try XCTUnwrap(SentrySDKInternal.getAppStartMeasurement())
        XCTAssertEqual(stored.type, .warm)
    }

    // MARK: - StandaloneTransactionStrategy

    func testSendStandalone_SDKNotEnabled_DoesNotCaptureTransaction() {
        let hub = createHub()
        // Don't set hub on SDK — isEnabled returns false
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        XCTAssertTrue(hub.capturedEventsWithScopes.invocations.isEmpty)
    }

    func testSendStandalone_ColdStart_CapturesTransaction() throws {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start Cold")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, "app.start.cold")
        XCTAssertEqual(traceContext["origin"] as? String, "auto.app.start")
    }

    func testSendStandalone_WarmStart_CapturesTransaction() throws {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        let measurement = createMeasurement(type: .warm)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start Warm")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, "app.start.warm")
    }

    func testSendStandalone_DoesNotSetGlobalStatic() {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement())
    }

    // MARK: - StandaloneTransactionStrategy Integration Tests

    private func setUpIntegrationHub() -> TestHub {
        let dateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = dateProvider

        let debugImageProvider = TestDebugImageProvider()
        debugImageProvider.debugImages = [TestData.debugImage]
        SentryDependencyContainer.sharedInstance().debugImageProvider = debugImageProvider

        let displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: dateProvider)
        SentryDependencyContainer.sharedInstance().framesTracker.setDisplayLinkWrapper(displayLinkWrapper)
        SentryDependencyContainer.sharedInstance().framesTracker.start()
        displayLinkWrapper.call()

        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "AppStartReportingStrategyTests")
        options.tracesSampleRate = 1
        let client = TestClient(options: options)
        let hub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)
        return hub
    }

    func testSendStandalone_ColdStart_AddsAppStartMeasurement() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold, duration: 0.5)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let measurements = try XCTUnwrap(serialized["measurements"] as? [String: Any])
        let appStartCold = try XCTUnwrap(measurements["app_start_cold"] as? [String: Any])
        XCTAssertEqual(appStartCold["value"] as? Double, 500)
    }

    func testSendStandalone_WarmStart_AddsAppStartMeasurement() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .warm, duration: 0.3)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let measurements = try XCTUnwrap(serialized["measurements"] as? [String: Any])
        let appStartWarm = try XCTUnwrap(measurements["app_start_warm"] as? [String: Any])
        XCTAssertEqual(appStartWarm["value"] as? Double, 300)
    }

    func testSendStandalone_AddsDebugMeta() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let debugMeta = try XCTUnwrap(serialized["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        let image = try XCTUnwrap(images.first)
        let expectedImage = TestData.debugImage
        XCTAssertEqual(image["code_file"] as? String, expectedImage.codeFile)
        XCTAssertEqual(image["image_addr"] as? String, expectedImage.imageAddress)
        XCTAssertEqual(image["image_vmaddr"] as? String, expectedImage.imageVmAddress)
    }

    func testSendStandalone_SetsStartTimeToAppStartTimestamp() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let startTimestamp = try XCTUnwrap(serialized["start_timestamp"] as? TimeInterval)
        XCTAssertEqual(
            startTimestamp,
            measurement.appStartTimestamp.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    /// Verifies the full span tree for a warm non-prewarmed standalone app start transaction.
    /// More span edge cases (cold, prewarmed, grouping span) are covered in SentryBuildAppStartSpansTests.
    func testSendStandalone_WarmNotPrewarmed_ContainsCorrectSpans() throws {
        let hub = setUpIntegrationHub()
        let dateProvider = TestCurrentDateProvider()
        let appStart = dateProvider.date()
        let measurement = SentryAppStartMeasurement(
            type: .warm,
            isPreWarmed: false,
            appStartTimestamp: appStart,
            runtimeInitSystemTimestamp: dateProvider.systemTime(),
            duration: 0.5,
            runtimeInitTimestamp: appStart.addingTimeInterval(0.05),
            moduleInitializationTimestamp: appStart.addingTimeInterval(0.1),
            sdkStartTimestamp: appStart.addingTimeInterval(0.15),
            didFinishLaunchingTimestamp: appStart.addingTimeInterval(0.3)
        )

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])

        // Warm non-prewarmed standalone: no grouping span, includes pre-runtime spans → 5 child spans
        XCTAssertEqual(spans.count, 5)

        let descriptions = spans.compactMap { $0["description"] as? String }
        XCTAssertEqual(descriptions, [
            "Pre Runtime Init",
            "Runtime Init to Pre Main Initializers",
            "UIKit Init",
            "Application Init",
            "Initial Frame Render"
        ])

        let operations = Set(spans.compactMap { $0["op"] as? String })
        XCTAssertEqual(operations, ["app.start.warm"])

        let appStartInterval = appStart.timeIntervalSince1970

        // Pre Runtime Init: appStart → runtimeInit
        assertSpanTimestamps(spans[0],
                             expectedStart: appStartInterval,
                             expectedEnd: appStartInterval + 0.05)
        // Runtime Init to Pre Main Initializers: runtimeInit → moduleInit
        assertSpanTimestamps(spans[1],
                             expectedStart: appStartInterval + 0.05,
                             expectedEnd: appStartInterval + 0.1)
        // UIKit Init: moduleInit → sdkStart
        assertSpanTimestamps(spans[2],
                             expectedStart: appStartInterval + 0.1,
                             expectedEnd: appStartInterval + 0.15)
        // Application Init: sdkStart → didFinishLaunching
        assertSpanTimestamps(spans[3],
                             expectedStart: appStartInterval + 0.15,
                             expectedEnd: appStartInterval + 0.3)
        // Initial Frame Render: didFinishLaunching → appStart + duration
        assertSpanTimestamps(spans[4],
                             expectedStart: appStartInterval + 0.3,
                             expectedEnd: appStartInterval + 0.5)
    }

    // MARK: - StandaloneAppStartTransactionHelper

    func testHelper_ColdStartWithAutoOrigin_ReturnsTrue() {
        XCTAssertTrue(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "app.start.cold",
            origin: "auto.app.start"
        ))
    }

    func testHelper_WarmStartWithAutoOrigin_ReturnsTrue() {
        XCTAssertTrue(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "app.start.warm",
            origin: "auto.app.start"
        ))
    }

    func testHelper_UILoadWithAutoOrigin_ReturnsFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "ui.load",
            origin: "auto.app.start"
        ))
    }

    func testHelper_ColdStartWithManualOrigin_ReturnsFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "app.start.cold",
            origin: "manual"
        ))
    }

    // MARK: - Helpers

    private func assertSpanTimestamps(
        _ span: [String: Any],
        expectedStart: TimeInterval,
        expectedEnd: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let start = span["start_timestamp"] as? TimeInterval ?? 0
        let end = span["timestamp"] as? TimeInterval ?? 0
        XCTAssertEqual(start, expectedStart, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(end, expectedEnd, accuracy: 0.001, file: file, line: line)
    }
}

#endif // os(iOS) || os(tvOS)
