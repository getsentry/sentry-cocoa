@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)

class SentryExtendedAppLaunchTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        SentryAppStartMeasurementProvider.reset()
    }

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
        options.dsn = TestConstants.dsnAsString(username: "SentryExtendedAppLaunchTests")
        options.tracesSampleRate = 1
        let client = TestClient(options: options)
        let hub = TestHub(client: client, andScope: Scope())
        SentrySDKInternal.setCurrentHub(hub)
        return hub
    }

    // MARK: - SentryExtendedAppLaunchManager

    func testExtend_setsFlag() {
        _ = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        XCTAssertFalse(manager.isExtendRequested)

        manager.extend()

        XCTAssertTrue(manager.isExtendRequested)
    }

    func testExtend_returnsSpan() {
        _ = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()

        let span = manager.extend()

        XCTAssertNotNil(span)
        XCTAssertEqual(span?.operation, SentrySpanOperationAppStart)
        XCTAssertEqual(span?.spanDescription, "Extended App Start")
        XCTAssertFalse(span?.isFinished ?? true)
    }

    func testExtend_beforeSDKStart_returnsNil() {
        addTeardownBlock { clearTestState() }
        let manager = SentryExtendedAppLaunchManager()

        let span = manager.extend()

        XCTAssertNil(span)
        XCTAssertFalse(manager.isExtendRequested)
    }

    func testFinish_withoutExtend_doesNotCrash() {
        let manager = SentryExtendedAppLaunchManager()
        manager.finish()
    }

    func testReset_clearsState() {
        _ = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()
        XCTAssertTrue(manager.isExtendRequested)

        manager.reset()

        XCTAssertFalse(manager.isExtendRequested)
    }

    // MARK: - StandaloneTransactionStrategy with Extended Launch

    func testReport_whenExtended_shouldNotFinishTransaction() {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()

        let measurement = createMeasurement(type: .cold)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())

        XCTAssertTrue(hub.capturedTransactionsWithScope.invocations.isEmpty,
            "Transaction should not be captured yet when launch is extended")
    }

    func testReport_whenNotExtended_shouldFinishTransactionImmediately() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()

        let measurement = createMeasurement(type: .cold)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        XCTAssertEqual(serialized["transaction"] as? String, "App Start")

        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: Any])
        let traceContext = try XCTUnwrap(contexts["trace"] as? [String: Any])
        XCTAssertEqual(traceContext["op"] as? String, "app.start")
        XCTAssertEqual(traceContext["origin"] as? String, "auto.app.start")

        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        XCTAssertFalse(spans.isEmpty, "Transaction should contain app start child spans")
    }

    func testFinishExtendedAppLaunch_capturesTransactionWithExtendedSpan() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()

        let measurement = createMeasurement(type: .cold, duration: 0.5)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        XCTAssertTrue(hub.capturedTransactionsWithScope.invocations.isEmpty, "Precondition")

        manager.finish()

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])

        let extendedSpans = spans.filter { ($0["description"] as? String) == "Extended App Start" }
        XCTAssertEqual(extendedSpans.count, 1)

        let extendedSpan = try XCTUnwrap(extendedSpans.first)
        XCTAssertEqual(extendedSpan["op"] as? String, "app.start")
    }

    func testFinishExtendedAppLaunch_extendedSpanStartsAtExtendCallTime() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        let beforeExtend = Date()
        manager.extend()
        let afterExtend = Date()

        let measurement = createMeasurement(type: .cold, duration: 0.5)

        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        manager.finish()

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        let extendedSpan = try XCTUnwrap(spans.first { ($0["description"] as? String) == "Extended App Start" })

        let startTimestamp = try XCTUnwrap(extendedSpan["start_timestamp"] as? TimeInterval)
        XCTAssertGreaterThanOrEqual(startTimestamp, beforeExtend.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(startTimestamp, afterExtend.timeIntervalSince1970)
    }

    func testFinishExtendedAppLaunch_secondCallIsNoop() {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()

        let measurement = createMeasurement(type: .cold)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())

        manager.finish()
        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1)

        manager.finish()
        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1,
            "Second finish call should be a no-op")
    }

    func testFinishExtendedAppLaunch_clearsExtendedFlag() {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()

        let measurement = createMeasurement(type: .cold)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        manager.finish()

        XCTAssertFalse(manager.isExtendRequested)
        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1)
    }

    func testExtendAfterAppStartCompleted_doesNotSetFlag() {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()

        let measurement = createMeasurement(type: .cold)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1, "Precondition: transaction finished immediately")

        manager.extend()

        XCTAssertFalse(manager.isExtendRequested,
            "extend() should be rejected after app start already completed")
    }

    func testFinishAfterAppStartCompleted_doesNotCaptureExtraTransaction() {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()

        let measurement = createMeasurement(type: .cold)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1, "Precondition")

        manager.extend()
        manager.finish()

        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1,
            "finish() should not capture another transaction when extend was rejected")
    }

    func testReport_whenWarmStartExtended_shouldWorkSameAsCold() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()

        let measurement = createMeasurement(type: .warm, duration: 0.3)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        XCTAssertTrue(hub.capturedTransactionsWithScope.invocations.isEmpty)

        manager.finish()

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        let extendedSpans = spans.filter { ($0["description"] as? String) == "Extended App Start" }
        XCTAssertEqual(extendedSpans.count, 1)
    }

    // MARK: - Returned Span Child Spans

    func testExtend_returnedSpan_canAddChildSpans() throws {
        _ = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        let span = manager.extend()

        let child = span?.startChild(operation: "app.init", description: "fetch remote config")
        XCTAssertNotNil(child)
        XCTAssertFalse(child?.isFinished ?? true)

        child?.finish()
        XCTAssertTrue(child?.isFinished ?? false)
    }

    func testExtend_childSpansIncludedInTransaction() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        let span = manager.extend()

        let measurement = createMeasurement(type: .cold, duration: 0.5)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())

        let child = span?.startChild(operation: "app.init", description: "fetch remote config")
        child?.finish()
        span?.finish()

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])

        let childSpans = spans.filter { ($0["description"] as? String) == "fetch remote config" }
        XCTAssertEqual(childSpans.count, 1)

        let childSpan = try XCTUnwrap(childSpans.first)
        XCTAssertEqual(childSpan["op"] as? String, "app.init")
    }

    func testExtend_finishingReturnedSpan_capturesTransaction() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        let span = manager.extend()

        let measurement = createMeasurement(type: .cold, duration: 0.5)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())
        XCTAssertTrue(hub.capturedTransactionsWithScope.invocations.isEmpty, "Precondition")

        span?.finish()

        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1,
            "Finishing the returned span should capture the transaction")
    }

    // MARK: - Span finished before measurement arrives

    func testExtend_spanFinishedBeforeReport_waitsForMeasurement() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        let span = manager.extend()

        span?.finish()

        XCTAssertTrue(hub.capturedTransactionsWithScope.invocations.isEmpty,
            "Transaction must not be captured before the app start measurement is available")

        let measurement = createMeasurement(type: .cold, duration: 0.5)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())

        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1,
            "Transaction should be captured once measurement arrives")

        let serialized = try XCTUnwrap(hub.capturedTransactionsWithScope.invocations.first?.transaction)
        let spans = try XCTUnwrap(serialized["spans"] as? [[String: Any]])
        let extendedSpans = spans.filter { ($0["description"] as? String) == "Extended App Start" }
        XCTAssertEqual(extendedSpans.count, 1)
    }

    func testExtend_finishViaManagerBeforeReport_waitsForMeasurement() throws {
        let hub = setUpIntegrationHub()
        let manager = SentryExtendedAppLaunchManager()
        manager.extend()

        manager.finish()

        XCTAssertTrue(hub.capturedTransactionsWithScope.invocations.isEmpty,
            "Transaction must not be captured before the app start measurement is available")

        let measurement = createMeasurement(type: .cold, duration: 0.5)
        StandaloneTransactionStrategy(extendedAppLaunchManager: manager).report(measurement, traceId: SentryId())

        XCTAssertEqual(hub.capturedTransactionsWithScope.invocations.count, 1,
            "Transaction should be captured once measurement arrives")
    }
}

#endif // os(iOS) || os(tvOS)
