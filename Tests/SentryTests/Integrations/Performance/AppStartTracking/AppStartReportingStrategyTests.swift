@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class AppStartReportingStrategyTests: XCTestCase {

    private func createMeasurement(type: SentryAppStartType, duration: TimeInterval = 0.5, isPreWarmed: Bool = false) -> SentryAppStartMeasurement {
        let dateProvider = TestCurrentDateProvider()
        let appStart = dateProvider.date()
        return SentryAppStartMeasurement(
            type: type,
            isPreWarmed: isPreWarmed,
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

    private func setCurrentHub() -> TestHub {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        addTeardownBlock { SentrySDKInternal.setCurrentHub(nil) }
        return hub
    }

    // MARK: - AttachToTransactionStrategy

    func testReport_whenColdStart_shouldSetMeasurementOnGlobalStatic() throws {
        addTeardownBlock { SentrySDKInternal.setAppStartMeasurement(nil) }
        let measurement = createMeasurement(type: .cold)

        AttachToTransactionStrategy().report(measurement)

        let stored = try XCTUnwrap(SentrySDKInternal.getAppStartMeasurement())
        XCTAssertEqual(stored.type, .cold)
        XCTAssertEqual(stored.duration, measurement.duration)
    }

    func testReport_whenWarmStart_shouldSetMeasurementOnGlobalStatic() throws {
        addTeardownBlock { SentrySDKInternal.setAppStartMeasurement(nil) }
        let measurement = createMeasurement(type: .warm)

        AttachToTransactionStrategy().report(measurement)

        let stored = try XCTUnwrap(SentrySDKInternal.getAppStartMeasurement())
        XCTAssertEqual(stored.type, .warm)
    }

    // MARK: - StandaloneTransactionStrategy

    func testReport_whenSDKNotEnabled_shouldNotCaptureTransaction() {
        let hub = createHub()
        // Don't set hub on SDK — isEnabled returns false
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        XCTAssertTrue(hub.capturedEventsWithScopes.invocations.isEmpty)
    }

    func testReport_whenColdStart_shouldCaptureTransaction() throws {
        let hub = setCurrentHub()
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, "app.start")
        XCTAssertEqual(traceContext["origin"] as? String, "auto.app.start")
    }

    func testReport_whenWarmStart_shouldCaptureTransaction() throws {
        let hub = setCurrentHub()
        let measurement = createMeasurement(type: .warm)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, "app.start")
    }

    func testReport_whenUnknownStartType_shouldCaptureTransactionWithSpansButNoMeasurements() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .unknown)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = serialized["spans"] as? [[String: Any]] ?? []
        XCTAssertFalse(spans.isEmpty, "Standalone uses unified op, so spans are built regardless of type")
        XCTAssertNil(serialized["measurements"], "Unknown start type should produce no measurements")
    }

    func testReport_whenColdStart_shouldNotSetGlobalStatic() {
        _ = setCurrentHub()
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement())
    }

    // MARK: - StandaloneTransactionStrategy Integration Tests

    private func setUpIntegrationHub() -> TestHub {
        addTeardownBlock { clearTestState() }

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

    func testReport_whenColdStart_shouldAddAppStartAttributes() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold, duration: 0.5)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let extra = try XCTUnwrap(serialized["extra"] as? [String: Any])
        let appStartCold = try XCTUnwrap(extra["app.vitals.start.cold.value"] as? NSNumber)
        XCTAssertEqual(appStartCold.doubleValue, 500, accuracy: 0.001)
    }

    func testReport_whenWarmStart_shouldAddAppStartAttributes() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .warm, duration: 0.3)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let extra = try XCTUnwrap(serialized["extra"] as? [String: Any])
        let appStartWarm = try XCTUnwrap(extra["app.vitals.start.warm.value"] as? NSNumber)
        XCTAssertEqual(appStartWarm.doubleValue, 300, accuracy: 0.001)
    }

    func testReport_whenNotPrewarmed_shouldSetPrewarmedAttributeToFalse() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold, isPreWarmed: false)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let extra = try XCTUnwrap(serialized["extra"] as? [String: Any])
        let prewarmed = try XCTUnwrap(extra["app.vitals.start.prewarmed"] as? NSNumber)
        XCTAssertFalse(prewarmed.boolValue)
    }

    func testReport_whenPrewarmed_shouldSetPrewarmedAttributeToTrue() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold, isPreWarmed: true)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let extra = try XCTUnwrap(serialized["extra"] as? [String: Any])
        let prewarmed = try XCTUnwrap(extra["app.vitals.start.prewarmed"] as? NSNumber)
        XCTAssertTrue(prewarmed.boolValue)
    }

    func testReport_whenScreenNameSet_shouldAddScreenAttribute() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold)
        SentryAppStartMeasurementProvider.setAppStartScreen("MainViewController")
        addTeardownBlock { SentryAppStartMeasurementProvider.reset() }

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let extra = try XCTUnwrap(serialized["extra"] as? [String: Any])
        let screen = try XCTUnwrap(extra["app.vitals.start.screen"] as? String)
        XCTAssertEqual(screen, "MainViewController")
    }

    func testReport_whenNoScreenNameSet_shouldNotAddScreenAttribute() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold)

        StandaloneTransactionStrategy().report(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let extra = serialized["extra"] as? [String: Any]
        XCTAssertNil(extra?["app.vitals.start.screen"])
    }

    func testReport_whenColdStart_shouldAddDebugMeta() throws {
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

    func testReport_whenColdStart_shouldSetStartTimeToAppStartTimestamp() throws {
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
    func testReport_whenWarmNotPrewarmed_shouldContainCorrectSpans() throws {
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
        XCTAssertEqual(operations, ["app.start"])

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

    func testIsStandaloneAppStartTransaction_whenAppStartWithAutoOrigin_shouldReturnTrue() {
        XCTAssertTrue(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "app.start",
            origin: "auto.app.start"
        ))
    }

    func testIsStandaloneAppStartTransaction_whenColdStartWithAutoOrigin_shouldReturnFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "app.start.cold",
            origin: "auto.app.start"
        ))
    }

    func testIsStandaloneAppStartTransaction_whenUILoadWithAutoOrigin_shouldReturnFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "ui.load",
            origin: "auto.app.start"
        ))
    }

    func testIsStandaloneAppStartTransaction_whenAppStartWithManualOrigin_shouldReturnFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "app.start",
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
