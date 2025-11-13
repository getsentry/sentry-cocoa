@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

// swiftlint:disable file_length
class SentryProfilingPublicAPITests: XCTestCase {
    private class Fixture {
        let options: Options = {
            let options = Options.noIntegrations()
            options.dsn = TestConstants.dsnAsString(username: "SentrySDKTests")
            options.releaseName = "1.0.0"
            return options
        }()

        let scope = {
            let scope = Scope()
            scope.setTag(value: "value", key: "key")
            return scope
        }()

        var sessionTracker: SessionTracker?

        var _random: TestRandom = TestRandom(value: 0.5)
        var random: TestRandom {
            get {
                _random
            }
            set(newValue) {
                _random = newValue
                SentryDependencyContainer.sharedInstance().random = newValue
            }
        }

        let currentDate = TestCurrentDateProvider()
        lazy var timerFactory = TestSentryNSTimerFactory(currentDateProvider: currentDate)
        lazy var client = TestClient(options: options)!
        lazy var hub = SentryHubInternal(client: client, andScope: scope)
    }

    private let fixture = Fixture()

    override class func setUp() {
        super.setUp()
        SentrySDKLogSupport.configure(true, diagnosticLevel: .debug)
    }

    override func setUp() {
        super.setUp()
        SentryDependencyContainer.sharedInstance().timerFactory = fixture.timerFactory
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.currentDate
    }

    override func tearDown() {
        super.tearDown()

        givenSdkWithHubButNoClient()

        if let autoSessionTracking = SentrySDKInternal.currentHub().installedIntegrations().first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }

        clearTestState()
    }
}

// MARK: continuous profiling v2
extension SentryProfilingPublicAPITests {
    func testSentryOptionsReportsContinuousProfilingV2Enabled() {
        // Arrange
        let options = Options()
        options.configureProfiling = { _ in }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertTrue(options.isContinuousProfilingEnabled())
    }

    func testSentryOptionsReportsContinuousProfilingV2Disabled_NilConfiguration() {
        // Arrange
        let options = Options()
        options.configureProfiling = nil

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isContinuousProfilingEnabled())
    }

    func testSentryOptionsReportsProfilingCorrelatedToTraces() {
        // Arrange
        let options = Options()
        options.configureProfiling = {
            $0.lifecycle = .trace
        }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertTrue(options.isProfilingCorrelatedToTraces())
    }

    func testSentryOptionsReportsProfilingNotCorrelatedToTraces_ManualLifecycle() {
        // Arrange
        let options = Options()
        options.configureProfiling = {
            $0.lifecycle = .manual // this is the default value, but made explicit here for clarity
        }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isProfilingCorrelatedToTraces())
    }

    func testSentryOptionsReportsProfilingNotCorrelatedToTraces_NilConfiguration() {
        // Arrange
        let options = Options()
        options.configureProfiling = nil

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isProfilingCorrelatedToTraces())
    }

    func testManuallyStartingAndStoppingContinuousProfilerV2Sampled() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
        }
        givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        try stopProfilerV2()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManuallyStartingAndStoppingContinuousProfilerV2NotSampled() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0
        }
        givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2BeforeStartingSDKDoesNotStartProfiler() {
        // Arrange - do nothing, simulating actions before starting sdk

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2AfterStoppingSDKDoesNotStartProfiler() {
        // Arrange
        givenSdkWithHub()

        // Act
        SentrySDK.close()
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2WithTraceLifeCycleDoesNotStartProfiler() {
        // Arrange
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
        }
        givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfilerV2TraceLifecycleZeroSampleRateDoesNotStartProfiler() throws {
        let span: any Span

        defer {
            // clean up
            span.finish()
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0
            $0.lifecycle = .trace
        }
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()
        fixture.currentDate.advance(by: 1)

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStoppingContinuousProfilerV2WithTraceLifeCycleDoesNotStopProfiler() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
        }
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()
        fixture.currentDate.advance(by: 1)
        let span = SentrySDK.startTransaction(name: "test", operation: "test")
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act - using manual stop method is a no-op in trace profile lifecycle mode
        try stopProfilerV2()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        fixture.currentDate.advance(by: 1)

        // Act - the current profile chunk will automatically finish
        span.finish()

        // Assert - profile chunk must complete
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange - simulate chunk completion
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()

        // Assert - profiler is stopped
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingTransactionWithoutTraceLifecycleDoesNotStartContinuousProfilerV2() {
        //arrange
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()

        // Act
        SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingTransactionWithTraceProfilingLifecycleWithTracingDisabledDoesNotStartContinuousProfilerV2() {
        let span: any Span

        defer {
            // clean up
            print("here")
            span.finish()
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
        }
        givenSdkWithHub()

        // Act - hold a reference to the tracer so it doesn't dealloc, which tries to clean up any existing profilers
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfilerV2ManualLifecycleStartWithSampleSessionDecisionYes() throws {
        defer {
            // clean up
            do {
                try stopProfilerV2()
            } catch {
                XCTFail("Stop profiler process threw error: \(error)")
            }
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
        }
        givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfilerV2ManualLifecycleStartWithSampleSessionDecisionNo() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0
        }
        givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionYesSessionSampleDecisionNo() throws {
        let span: any Span

        defer {
            // clean up
            span.finish()
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0
            $0.lifecycle = .trace
        }
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionNoSessionSampleDecisionNo() throws {
        let span: any Span

        defer {
            // clean up
            span.finish()
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0
            $0.lifecycle = .trace
        }
        fixture.options.tracesSampleRate = 0
        givenSdkWithHub()

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionYesSessionSampleDecisionYes() throws {
        let span: any Span

        defer {
            // clean up
            span.finish()
            fixture.currentDate.advance(by: 60)
            do {
                try fixture.timerFactory.check()
            } catch {
                XCTFail("Checking timer state threw error: \(error)")
            }
            XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionNoSessionSampleDecisionYes() throws {
        let span: any Span

        defer {
            // clean up
            span.finish()
        }

        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        fixture.options.tracesSampleRate = 0
        givenSdkWithHub()

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

#if !os(macOS)
    func testSessionSampleRateReevaluationOnAppBecomingActive() {
        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0.5
            $0.lifecycle = .manual
        }
        fixture.random = TestRandom(value: 0)
        let container = SentryDependencyContainer.sharedInstance()
        let nc = container.notificationCenterWrapper
        let application = container.application()
        fixture.sessionTracker = SessionTracker(
            options: fixture.options,
            applicationProvider: { application },
            dateProvider: fixture.currentDate,
            notificationCenter: nc
        )
        fixture.sessionTracker?.start()
        givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        nc.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        fixture.random = TestRandom(value: 1)

        // Act
        nc.post(Notification(name: UIApplication.didBecomeActiveNotification))
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
#endif // !os(macOS)
}

private extension SentryProfilingPublicAPITests {
    func givenSdkWithHub() {
        SentrySDKInternal.setCurrentHub(fixture.hub)
        SentrySDK.setStart(with: fixture.options)
        sentry_sdkInitProfilerTasks(fixture.options, fixture.hub)
    }

    func givenSdkWithHubButNoClient() {
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))
        SentrySDK.setStart(with: fixture.options)
    }

    func stopProfiler() throws {
        SentrySDK.stopProfiler()
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()
    }

    func stopProfilerV2() throws {
        SentrySDK.stopProfiler()
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
