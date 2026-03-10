import _SentryPrivate
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class AppStartMeasurementHandlerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        SentrySDKInternal.setCurrentHub(nil)
        SentrySDKInternal.setAppStartMeasurement(nil)
        SentryAppStartMeasurementProvider.reset()
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
        options.dsn = TestConstants.dsnAsString(username: "AppStartMeasurementHandlerTests")
        options.tracesSampleRate = 1
        let client = TestClient(options: options)
        return TestHub(client: client, andScope: Scope())
    }

    // MARK: - AttachAppStartMeasurementHandler

    func testAttach_SetsMeasurementOnGlobalStatic() throws {
        let measurement = createMeasurement(type: .cold)

        AttachAppStartMeasurementHandler().handle(measurement)

        let stored = try XCTUnwrap(SentrySDKInternal.getAppStartMeasurement())
        XCTAssertEqual(stored.type, .cold)
        XCTAssertEqual(stored.duration, measurement.duration)
    }

    func testAttach_WarmStart_SetsMeasurementOnGlobalStatic() throws {
        let measurement = createMeasurement(type: .warm)

        AttachAppStartMeasurementHandler().handle(measurement)

        let stored = try XCTUnwrap(SentrySDKInternal.getAppStartMeasurement())
        XCTAssertEqual(stored.type, .warm)
    }

    // MARK: - SendStandaloneAppStartTransaction

    func testSendStandalone_SDKNotEnabled_DoesNotCaptureTransaction() {
        let hub = createHub()
        // Don't set hub on SDK — isEnabled returns false
        let measurement = createMeasurement(type: .cold)

        SendStandaloneAppStartTransaction().handle(measurement)

        XCTAssertTrue(hub.capturedEventsWithScopes.invocations.isEmpty)
    }

    func testSendStandalone_ColdStart_CapturesTransaction() throws {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        let measurement = createMeasurement(type: .cold)

        SendStandaloneAppStartTransaction().handle(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start Cold")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, SentrySpanOperationAppStartCold)
        XCTAssertEqual(traceContext["origin"] as? String, SentryTraceOriginAutoAppStart)
    }

    func testSendStandalone_WarmStart_CapturesTransaction() throws {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        let measurement = createMeasurement(type: .warm)

        SendStandaloneAppStartTransaction().handle(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start Warm")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, SentrySpanOperationAppStartWarm)
    }

    func testSendStandalone_DoesNotSetGlobalStatic() {
        let hub = createHub()
        SentrySDKInternal.setCurrentHub(hub)
        let measurement = createMeasurement(type: .cold)

        SendStandaloneAppStartTransaction().handle(measurement)

        XCTAssertNil(SentrySDKInternal.getAppStartMeasurement())
    }

    // MARK: - SendStandaloneAppStartTransaction Integration Tests

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
        options.dsn = TestConstants.dsnAsString(username: "AppStartMeasurementHandlerTests")
        options.tracesSampleRate = 1
        let client = TestClient(options: options)
        let hub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)
        return hub
    }

    func testSendStandalone_ColdStart_AddsAppStartMeasurement() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold, duration: 0.5)

        SendStandaloneAppStartTransaction().handle(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let measurements = try XCTUnwrap(serialized["measurements"] as? [String: Any])
        let appStartCold = try XCTUnwrap(measurements["app_start_cold"] as? [String: Any])
        XCTAssertEqual(appStartCold["value"] as? Double, 500)
    }

    func testSendStandalone_WarmStart_AddsAppStartMeasurement() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .warm, duration: 0.3)

        SendStandaloneAppStartTransaction().handle(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let measurements = try XCTUnwrap(serialized["measurements"] as? [String: Any])
        let appStartWarm = try XCTUnwrap(measurements["app_start_warm"] as? [String: Any])
        XCTAssertEqual(appStartWarm["value"] as? Double, 300)
    }

    func testSendStandalone_AddsDebugMeta() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold)

        SendStandaloneAppStartTransaction().handle(measurement)

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let debugMeta = try XCTUnwrap(serialized["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty)
    }

    func testSendStandalone_SetsStartTimeToAppStartTimestamp() throws {
        let hub = setUpIntegrationHub()
        let measurement = createMeasurement(type: .cold)

        SendStandaloneAppStartTransaction().handle(measurement)

        let event = try XCTUnwrap(hub.capturedEventsWithScopes.invocations.first?.event)
        let eventStartTimestamp = try XCTUnwrap(event.startTimestamp)
        XCTAssertEqual(
            eventStartTimestamp.timeIntervalSinceReferenceDate,
            measurement.appStartTimestamp.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    // MARK: - StandaloneAppStartTransactionHelper

    func testHelper_ColdStartWithAutoOrigin_ReturnsTrue() {
        XCTAssertTrue(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: SentrySpanOperationAppStartCold,
            origin: SentryTraceOriginAutoAppStart
        ))
    }

    func testHelper_WarmStartWithAutoOrigin_ReturnsTrue() {
        XCTAssertTrue(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: SentrySpanOperationAppStartWarm,
            origin: SentryTraceOriginAutoAppStart
        ))
    }

    func testHelper_UILoadWithAutoOrigin_ReturnsFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: "ui.load",
            origin: SentryTraceOriginAutoAppStart
        ))
    }

    func testHelper_ColdStartWithManualOrigin_ReturnsFalse() {
        XCTAssertFalse(StandaloneAppStartTransactionHelper.isStandaloneAppStartTransaction(
            operation: SentrySpanOperationAppStartCold,
            origin: "manual"
        ))
    }
}

#endif // os(iOS) || os(tvOS)
