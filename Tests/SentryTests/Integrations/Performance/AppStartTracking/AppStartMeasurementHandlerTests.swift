@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class AppStartMeasurementHandlerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
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
