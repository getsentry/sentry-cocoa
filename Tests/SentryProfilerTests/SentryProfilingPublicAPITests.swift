@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

// swiftlint:disable file_length
class SentryProfilingPublicAPITests: XCTestCase {
    private var fixture: SentryProfileTestFixture!

    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()

        if let autoSessionTracking = SentrySDK.currentHub().installedIntegrations().first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }

        clearTestState()
    }
}

// MARK: transaction profiling
extension SentryProfilingPublicAPITests {
    func testSentryOptionsReportsProfilingCorrelatedToTraces_NonnilSampleRate() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = 1
        options.profilesSampler = nil
        options.configureProfiling = {
            $0.lifecycle = .trace
        }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertTrue(options.isProfilingCorrelatedToTraces())
    }

    func testSentryOptionsReportsProfilingCorrelatedToTraces_NonnilSampler() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = { _ in 1 }
        options.configureProfiling = {
            $0.lifecycle = .trace
        }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertTrue(options.isProfilingCorrelatedToTraces())
    }
}

// MARK: continuous profiling v1
extension SentryProfilingPublicAPITests {
    func testSentryOptionsReportsContinuousProfilingEnabled() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = nil

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertTrue(options.isContinuousProfilingEnabled())
    }

    func testSentryOptionsReportsContinuousProfilingDisabledWithNonnilSampleRate() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = 1
        options.profilesSampler = nil

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isContinuousProfilingEnabled())
    }

    func testSentryOptionsReportsContinuousProfilingDisabledWithNonnilSampler() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = { _ in 1 }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isContinuousProfilingEnabled())
    }

    func testStartingContinuousProfilerV1WithSampleRateZero() throws {
        fixture.givenSdkWithHub()

        fixture.options.profilesSampleRate = 0
        XCTAssertEqual(try XCTUnwrap(fixture.options.profilesSampleRate).doubleValue, 0)

        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV1WithSampleRateNil() throws {
        fixture.options.profilesSampleRate = nil
        fixture.givenSdkWithHub()

        // nil is the default initial value for profilesSampleRate, so we don't have to explicitly set it on the fixture
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        try fixture.stopContinuousProfiler()
    }

    func testNotStartingContinuousProfilerV1WithSampleRateBlock() throws {
        fixture.givenSdkWithHub()

        fixture.options.profilesSampler = { _ in 0 }
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testNotStartingContinuousProfilerV1WithSampleRateNonZero() throws {
        fixture.givenSdkWithHub()

        fixture.options.profilesSampleRate = 1
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingAndStoppingContinuousProfilerV1() throws {
        fixture.options.profilesSampleRate = nil
        fixture.givenSdkWithHub()
        SentrySDK.startProfiler()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        try fixture.stopContinuousProfiler()

        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV1BeforeStartingSDK() {
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV1AfterStoppingSDK() {
        fixture.givenSdkWithHub()
        SentrySDK.close()
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}

// MARK: continuous profiling v2
extension SentryProfilingPublicAPITests {
    func testSentryOptionsReportsContinuousProfilingV2Enabled() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = nil
        options.configureProfiling = { _ in }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertTrue(options.isContinuousProfilingV2Enabled())
    }

    func testSentryOptionsReportsContinuousProfilingV2Disabled_NonnilSampleRate() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = 1
        options.profilesSampler = nil
        options.configureProfiling = { _ in }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isContinuousProfilingV2Enabled())
    }

    func testSentryOptionsReportsContinuousProfilingV2Disabled_NonnilSampler() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = { _ in 1 }
        options.configureProfiling = { _ in }

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isContinuousProfilingV2Enabled())
    }

    func testSentryOptionsReportsContinuousProfilingV2Disabled_NilConfiguration() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = nil
        options.configureProfiling = nil

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isContinuousProfilingV2Enabled())
    }

    func testSentryOptionsReportsProfilingCorrelatedToTraces() {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
        options.profilesSampler = nil
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
        options.profilesSampleRate = nil
        options.profilesSampler = nil
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
        options.profilesSampleRate = nil
        options.profilesSampler = nil
        options.configureProfiling = nil

        // Act
        sentry_configureContinuousProfiling(options)

        // Assert
        XCTAssertFalse(options.isProfilingCorrelatedToTraces())
    }

    func testManuallyStartingAndStoppingContinuousProfilerV2Sampled() throws {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
        }
        fixture.givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        try fixture.stopContinuousProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManuallyStartingAndStoppingContinuousProfilerV2NotSampled() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0
        }
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()

        // Act
        SentrySDK.close()
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2WithoutContinuousProfilingEnabledDoesNotStartProfiler() {
        // Arrange
        fixture.options.profilesSampleRate = 1
        fixture.givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2WithTraceLifeCycleDoesNotStartProfiler() {
        // Arrange
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
        }
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()
        fixture.currentDateProvider.advance(by: 1)

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStoppingContinuousProfilerV2WithTraceLifeCycleDoesNotStopProfiler() throws {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
        }
        fixture.givenSdkWithHub()
        fixture.currentDateProvider.advance(by: 1)
        let span = SentrySDK.startTransaction(name: "test", operation: "test")
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act - using manual stop method is a no-op in trace profile lifecycle mode
        try fixture.stopContinuousProfiler()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        fixture.currentDateProvider.advance(by: 1)

        // Act - the current profile chunk will automatically finish
        span.finish()

        // Assert - profile chunk must complete
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange - simulate chunk completion
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert - profiler is stopped
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingTransactionWithoutTraceLifecycleDoesNotStartContinuousProfilerV2() {
        //arrange
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()

        // Act - hold a reference to the tracer so it doesn't dealloc, which tries to clean up any existing profilers
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfilerV2ManualLifecycleStartWithSampleSessionDecisionYes() throws {
        defer {
            // clean up
            do {
                try fixture.stopContinuousProfiler()
            } catch {
                XCTFail("Stop profiler process threw error: \(error)")
            }
        }

        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
        }
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()

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
            fixture.currentDateProvider.advance(by: 60)
            do {
                try fixture.timeoutTimerFactory.check()
            } catch {
                XCTFail("Checking timer state threw error: \(error)")
            }
            XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        }

        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        fixture.givenSdkWithHub()

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
        fixture.givenSdkWithHub()

        // Act
        span = SentrySDK.startTransaction(name: "test", operation: "test")

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

#if !os(macOS)
    func testContinuousProfileV2SessionSampleRateReevaluationOnAppBecomingActive() {
        // Arrange
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 0.5
            $0.lifecycle = .manual
        }
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0)
        fixture.sessionTracker?.start()
        fixture.givenSdkWithHub()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 1)

        // Act
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
#endif // !os(macOS)
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
