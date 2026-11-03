#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import SentryTestUtilsObjC
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import XCTest

// swiftlint:disable file_length
class SentryProfilingPublicAPITests: XCTestCase {
    private class Fixture {
        let options: Options = {
            let options = Options.noIntegrations()
            options.dsn = TestConstants.dsnAsString(username: "SentrySDKTests")
            options.releaseName = "1.0.0"
            options.enableAutoSessionTracking = false
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
        let notificationCenter = TestNSNotificationCenterWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
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
        fixture.sessionTracker?.removeObservers()
        fixture.sessionTracker = nil

        super.tearDown()

        givenSdkWithHubButNoClient()

        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
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
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        try stopProfilerV2()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testManuallyStartingContinuousProfilerV2BeforePendingStopCompletesKeepsProfiling() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.sessionSampleRate = 1
        }
        givenSdkWithHub()
        SentrySDK.startProfiler()
        SentrySDK.stopProfiler()

        // Act
        SentrySDK.startProfiler()
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Clean up
        try stopProfilerV2()
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
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act - using manual stop method is a no-op in trace profile lifecycle mode
        try stopProfilerV2()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        fixture.currentDate.advance(by: 1)

        // Act - the current profile chunk will automatically finish
        span.finish()

        // Assert - profile chunk must complete
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

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
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
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
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
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

#if !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    func testSessionSampleRateReevaluationOnAppBecomingActive_whenNewSessionStarts_shouldReevaluate() {
        // Arrange
        fixture.options.sessionTrackingIntervalMillis = 10_000
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
            notificationCenter: nc,
            dispatchQueue: TestSentryDispatchQueueWrapper()
        )
        givenSdkWithHub()
        fixture.sessionTracker?.start()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        nc.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        fixture.random = TestRandom(value: 1)
        fixture.currentDate.advance(by: 10)

        // Act
        nc.post(Notification(name: UIApplication.didBecomeActiveNotification))
        SentrySDK.startProfiler()

        // Assert
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testSessionSampleRateReevaluationOnAppBecomingActive_whenSameSession_shouldNotReevaluate() {
        // Arrange
        fixture.options.sessionTrackingIntervalMillis = 10_000
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
            notificationCenter: nc,
            dispatchQueue: TestSentryDispatchQueueWrapper()
        )
        givenSdkWithHub()
        fixture.sessionTracker?.start()

        // Act
        SentrySDK.startProfiler()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act
        nc.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Arrange
        fixture.random = TestRandom(value: 1)
        fixture.currentDate.advance(by: 9)

        // Act
        nc.post(Notification(name: UIApplication.didBecomeActiveNotification))
        SentrySDK.startProfiler()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }
#endif // !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
}

// MARK: Trace lifecycle ownership
extension SentryProfilingPublicAPITests {
    func testFinish_whenOlderRootFinishesFirst_shouldKeepProfilingUntilLastRootFinishes() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let olderRoot = SentrySDK.startTransaction(name: "older", operation: "test")
        let newerRoot = SentrySDK.startTransaction(name: "newer", operation: "test")
        defer {
            olderRoot.finish()
            newerRoot.finish()
        }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())

        // -- Act --
        olderRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertTrue(profiler === SentryContinuousProfiler.profiler())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)

        // -- Act --
        newerRoot.finish()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 2)
    }

    func testFinish_whenNewerRootFinishesFirst_shouldKeepProfilingUntilLastRootFinishes() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let olderRoot = SentrySDK.startTransaction(name: "older", operation: "test")
        let newerRoot = SentrySDK.startTransaction(name: "newer", operation: "test")
        defer {
            olderRoot.finish()
            newerRoot.finish()
        }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())

        // -- Act --
        newerRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertTrue(profiler === SentryContinuousProfiler.profiler())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)

        // -- Act --
        olderRoot.finish()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 2)
    }

    func testStartTransaction_whenLastRootStopIsPending_shouldKeepSameProfilerRunning() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let firstRoot = SentrySDK.startTransaction(name: "first", operation: "test")
        defer { firstRoot.finish() }
        let profiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        firstRoot.finish()

        // -- Act --
        let nextRoot = SentrySDK.startTransaction(name: "next", operation: "test")
        defer { nextRoot.finish() }
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertTrue(profiler === SentryContinuousProfiler.profiler())

        // -- Act --
        nextRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 2)
    }

    func testFinish_whenChildFinishesBeforeRoot_shouldNotReleaseRootOwnership() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let root = SentrySDK.startTransaction(name: "root", operation: "test")
        let child = root.startChild(operation: "child")
        defer {
            child.finish()
            root.finish()
        }

        // -- Act --
        child.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 0)

        // -- Act --
        root.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
    }

    func testStartTransaction_whenContextHasParent_shouldNotOwnProfiler() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let context = TransactionContext(
            name: "remote-child", nameSource: .custom, operation: "test", origin: "manual",
            trace: SentryId(), spanId: SpanId(), parentSpanId: SpanId(),
            parentSampled: .yes, parentSampleRate: 1, parentSampleRand: 0.5
        )
        let remoteChild = SentrySDK.startTransaction(transactionContext: context)
        defer { remoteChild.finish() }
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        let root = SentrySDK.startTransaction(name: "root", operation: "test")
        defer { root.finish() }
        root.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(remoteChild.isFinished)
    }

    /**
     Given an active native root and a hybrid discard with no associated profiler,
     when the hybrid API receives the discard repeatedly,
     then the native root retains ownership until it finishes.
     */
    func testDiscard_whenHybridTraceHasNoProfiler_shouldPreserveNativeRootOwnership() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let root = SentrySDK.startTransaction(name: "native", operation: "test")
        defer { root.finish() }
        let unknownTraceID = SentryId()

        // -- Act --
        SentrySDK.internal.profiling.discard(for: unknownTraceID)
        SentrySDK.internal.profiling.discard(for: unknownTraceID)
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        root.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testDealloc_whenAnotherRootIsActive_shouldReleaseOnlyAbandonedRoot() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let remainingRoot = SentrySDK.startTransaction(name: "remaining", operation: "test")
        defer { remainingRoot.finish() }
        weak var abandonedRoot: SentryTracer?

        // -- Act --
        autoreleasepool {
            let root = SentrySDK.startTransaction(name: "abandoned", operation: "test")
            abandonedRoot = root as? SentryTracer
            XCTAssertNotNil(abandonedRoot)
        }
        try completeProfileChunk()

        // -- Assert --
        XCTAssertNil(abandonedRoot)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 0)

        // -- Act --
        remainingRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
    }

    func testFinish_whenRootIsFinishedRepeatedlyThenDeallocated_shouldReleaseOwnershipOnce() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let remainingRoot = SentrySDK.startTransaction(name: "remaining", operation: "test")
        defer { remainingRoot.finish() }
        weak var finishedRoot: SentryTracer?

        // -- Act --
        autoreleasepool {
            let root = SentrySDK.startTransaction(name: "finished", operation: "test")
            finishedRoot = root as? SentryTracer
            root.finish()
            root.finish()
            XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
            // Captured transactions and recorded capture blocks retain their tracer.
            fixture.client.captureEventWithScopeInvocations.removeAll()
            fixture.dispatchQueueWrapper.dispatchAsyncInvocations.removeAll()
        }
        try completeProfileChunk()

        // -- Assert --
        XCTAssertNil(finishedRoot)
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 0)

        // -- Act --
        remainingRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
    }

#if !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    /**
     Given native and hybrid profiling sessions interrupted by backgrounding,
     when the hybrid session is discarded and a new native root starts,
     then hybrid tracking is released without consuming either native root's ownership.
     Finishing the older native root must leave profiling active for the newer root.
     */
    func testDiscard_whenHybridTraceIsBackgrounded_shouldReleaseOnlyHybridOwnership() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let originalRoot = SentrySDK.startTransaction(name: "original", operation: "test")
        defer { originalRoot.finish() }
        let hybridTraceID = SentryId()
        _ = SentrySDK.internal.profiling.start(for: hybridTraceID)
        defer { SentrySDK.internal.profiling.discard(for: hybridTraceID) }
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 1)
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // -- Act --
        SentrySDK.internal.profiling.discard(for: hybridTraceID)

        // -- Assert --
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), 0)

        // -- Act --
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))
        let newRoot = SentrySDK.startTransaction(name: "new", operation: "test")
        defer { newRoot.finish() }
        originalRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        newRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 2)
    }

    func testStartTransaction_whenForegroundedWithAnActiveRoot_shouldRestartProfiling() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let originalRoot = SentrySDK.startTransaction(name: "original", operation: "test")
        defer { originalRoot.finish() }
        let originalProfiler = try XCTUnwrap(SentryContinuousProfiler.profiler())
        let originalTimer = try XCTUnwrap(fixture.timerFactory.overrides?.timer)
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(originalTimer.isValid)
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))

        // -- Act --
        let newRoot = SentrySDK.startTransaction(name: "new", operation: "test")
        defer { newRoot.finish() }

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(originalProfiler === SentryContinuousProfiler.profiler())

        // -- Act --
        originalRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        newRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 2)
    }

    func testDealloc_whenRootIsAbandonedInBackground_shouldAllowNextRootToFinishProfiling() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        weak var abandonedRoot: SentryTracer?

        // -- Act --
        autoreleasepool {
            let root = SentrySDK.startTransaction(name: "abandoned", operation: "test")
            abandonedRoot = root as? SentryTracer
            fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
            XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        }
        XCTAssertNil(abandonedRoot)
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))
        let newRoot = SentrySDK.startTransaction(name: "new", operation: "test")
        defer { newRoot.finish() }
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        newRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 1)
    }

    func testFinish_whenRootFinishesInBackground_shouldAllowNextRootToFinishProfiling() throws {
        // -- Arrange --
        givenTraceLifecycleSDK()
        let originalRoot = SentrySDK.startTransaction(name: "original", operation: "test")
        defer { originalRoot.finish() }
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // -- Act --
        originalRoot.finish()
        fixture.notificationCenter.post(Notification(name: UIApplication.didBecomeActiveNotification))
        let newRoot = SentrySDK.startTransaction(name: "new", operation: "test")
        defer { newRoot.finish() }
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        newRoot.finish()
        try completeProfileChunk()

        // -- Assert --
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertEqual(fixture.client.captureEventWithScopeInvocations.count, 2)
    }
#endif // !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
}

private extension SentryProfilingPublicAPITests {
    func givenTraceLifecycleSDK() {
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
        }
        fixture.options.tracesSampleRate = 1
        let container = SentryDependencyContainer.sharedInstance()
        container.notificationCenterWrapper = fixture.notificationCenter
        container.dispatchQueueWrapper = fixture.dispatchQueueWrapper
        givenSdkWithHub()
    }

    func completeProfileChunk() throws {
        fixture.currentDate.advance(by: 60)
        try fixture.timerFactory.check()
    }

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

#endif
