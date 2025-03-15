@testable import Sentry
import SentryTestUtils
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

        let random = TestRandom(value: 0.5)
        let currentDate = TestCurrentDateProvider()
        lazy var timerFactory = TestSentryNSTimerFactory(currentDateProvider: currentDate)
        lazy var client = TestClient(options: options)!
        lazy var hub = SentryHub(client: client, andScope: scope)
    }

    private let fixture = Fixture()

    override func setUp() {
        super.setUp()
        SentryDependencyContainer.sharedInstance().random = fixture.random
        SentryDependencyContainer.sharedInstance().timerFactory = fixture.timerFactory
        SentryDependencyContainer.sharedInstance().dateProvider = fixture.currentDate
    }

    override func tearDown() {
        super.tearDown()

        givenSdkWithHubButNoClient()

        if let autoSessionTracking = SentrySDK.currentHub().installedIntegrations().first(where: { it in
            it is SentryAutoSessionTrackingIntegration
        }) as? SentryAutoSessionTrackingIntegration {
            autoSessionTracking.stop()
        }

        clearTestState()
    }
}

extension SentryProfilingPublicAPITests {
    func testStartingContinuousProfilerWithSampleRateZero() throws {
        givenSdkWithHub()

        fixture.options.profilesSampleRate = 0
        XCTAssertEqual(try XCTUnwrap(fixture.options.profilesSampleRate).doubleValue, 0)

        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerWithSampleRateNil() throws {
        givenSdkWithHub()

        // nil is the default initial value for profilesSampleRate, so we don't have to explicitly set it on the fixture
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        try stopProfiler()
    }

    func testNotStartingContinuousProfilerWithSampleRateBlock() throws {
        givenSdkWithHub()

        fixture.options.profilesSampler = { _ in 0 }
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testNotStartingContinuousProfilerWithSampleRateNonZero() throws {
        givenSdkWithHub()

        fixture.options.profilesSampleRate = 1
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingAndStoppingContinuousProfiler() throws {
        givenSdkWithHub()
        SentrySDK.startProfiler()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        try stopProfiler()

        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerBeforeStartingSDK() {
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerAfterStoppingSDK() {
        givenSdkWithHub()
        SentrySDK.close()
        SentrySDK.startProfiler()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManuallyStartingAndStoppingContinuousProfilerV2Sampled() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 1
        givenSdkWithHub()

        // act
        SentrySDK.startProfileSession()

        // assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // act
        try stopProfilerV2()

        // assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManuallyStartingAndStoppingContinuousProfilerV2NotSampled() throws {
        fixture.options.profiling.sessionSampleRate = 0
        givenSdkWithHub()
        SentrySDK.startProfileSession()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2BeforeStartingSDKDoesNotStartProfiler() {
        SentrySDK.startProfileSession()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2AfterStoppingSDKDoesNotStartProfiler() {
        givenSdkWithHub()
        SentrySDK.close()
        SentrySDK.startProfileSession()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2WithoutContinuousProfilingEnabledDoesNotStartProfiler() {
        fixture.options.profilesSampleRate = 1
        givenSdkWithHub()
        SentrySDK.startProfileSession()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingContinuousProfilerV2WithTraceLifeCycleDoesNotStartProfiler() {
        fixture.options.profiling.lifecycle = .trace
        givenSdkWithHub()
        SentrySDK.startProfileSession()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfilerV2TraceLifecycleZeroSampleRateDoesNotStartProfiler() throws {
        // arrange
        fixture.options.profiling.lifecycle = .trace
        fixture.options.profiling.sessionSampleRate = 0
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()
        fixture.currentDate.advance(by: 1)

        // act
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")

        // assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        trace.finish()
    }

    func testStoppingContinuousProfilerV2WithTraceLifeCycleDoesNotStopProfiler() throws {
        // arrange
        fixture.options.profiling.lifecycle = .trace
        fixture.options.profiling.sessionSampleRate = 1
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()
        fixture.currentDate.advance(by: 1)
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // act - using manual stop method is a no-op in trace profile lifecycle mode
        try stopProfilerV2()

        // assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // arrange
        fixture.currentDate.advance(by: 1)

        // act - the current profile chunk will automatically finish
        trace.finish()

        // assert - profile chunk must complete
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // arrange - simulate chunk completion
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()

        // assert - profiler is stopped
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingTransactionWithoutTraceLifecycleDoesNotStartContinuousProfilerV2() {
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()
        SentrySDK.startTransaction(name: "test", operation: "test")
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testStartingTransactionWithTraceProfilingLifecycleWithTracingDisabledDoesNotStartContinuousProfilerV2() {
        fixture.options.profiling.lifecycle = .trace
        givenSdkWithHub()

        // hold a reference to the tracer so it doesn't dealloc, which tries to clean up any existing profilers
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        trace.finish()
    }

    func testContinuousProfilerV2ManualLifecycleStartWithSampleSessionDecisionYes() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 1
        givenSdkWithHub()

        // act
        SentrySDK.startProfileSession()

        // assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        try stopProfilerV2()
    }

    func testContinuousProfilerV2ManualLifecycleStartWithSampleSessionDecisionNo() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 0
        givenSdkWithHub()

        // act
        SentrySDK.startProfileSession()

        // assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionYesSessionSampleDecisionNo() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 0
        fixture.options.profiling.lifecycle = .trace
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()

        // act
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")

        // assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        trace.finish()
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionNoSessionSampleDecisionNo() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 0
        fixture.options.profiling.lifecycle = .trace
        fixture.options.tracesSampleRate = 0
        givenSdkWithHub()

        // act
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")

        // assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        trace.finish()
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionYesSessionSampleDecisionYes() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 1
        fixture.options.profiling.lifecycle = .trace
        fixture.options.tracesSampleRate = 1
        givenSdkWithHub()

        // act
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")

        // assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        trace.finish()
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousProfileV2TraceLifecycleTracesSampleDecisionNoSessionSampleDecisionYes() throws {
        // arrange
        fixture.options.profiling.sessionSampleRate = 1
        fixture.options.profiling.lifecycle = .trace
        fixture.options.tracesSampleRate = 0
        givenSdkWithHub()

        // act
        let trace = SentrySDK.startTransaction(name: "test", operation: "test")

        // assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // clean up
        trace.finish()
    }
}

private extension SentryProfilingPublicAPITests {
    func givenSdkWithHub() {
        SentrySDK.setCurrentHub(fixture.hub)
        SentrySDK.setStart(fixture.options)
        sentry_sdkInitProfilerTasks(fixture.options, fixture.hub)
    }

    func givenSdkWithHubButNoClient() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))
        SentrySDK.setStart(fixture.options)
    }

    func stopProfiler() throws {
        SentrySDK.stopProfiler()
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()
    }

    func stopProfilerV2() throws {
        SentrySDK.stopProfileSession()
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
