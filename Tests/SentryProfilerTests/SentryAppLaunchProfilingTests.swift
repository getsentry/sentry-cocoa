#if (!SWIFT_PACKAGE || !SDK_V10) && (os(iOS) || os(macOS))
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryTestUtilsObjC
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryAppLaunchProfilingTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!

    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
}

// MARK: continuous profiling v2
extension SentryAppLaunchProfilingTests {
    func testContinuousLaunchProfileV2TraceLifecycleConfiguration() throws {
        // Arrange
        let options = Options()
        options.tracesSampleRate = 1
        options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }

        // Assert
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // Act
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssertTrue(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.profilesSampleRate]), 1)
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.profilesSampleRand]), 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.tracesSampleRate]), 1)
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.tracesSampleRand]), 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.continuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.trace.rawValue)

        // Act
        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testContinuousLaunchProfileV2ManualLifecycleConfiguration() throws {
        // Arrange
        let options = Options()
        options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }

        // Assert
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // Act
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssertTrue(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.profilesSampleRate]), 1)
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.profilesSampleRand]), 0.5)
        XCTAssertNil(dict[SentryLaunchProfileConfigKey.tracesSampleRate])
        XCTAssertNil(dict[SentryLaunchProfileConfigKey.tracesSampleRand])
        XCTAssertEqual(try XCTUnwrap(dict[SentryLaunchProfileConfigKey.continuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.manual.rawValue)

        // Act
        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}

// MARK: continuous profiling v2 (iOS-only)
#if !os(macOS)
extension SentryAppLaunchProfilingTests {
    func testLaunchContinuousProfileV2TraceLifecycleNotStoppedOnFullyDisplayed() throws {
        // Arrange
        fixture.options.tracesSampleRate = 1
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options)
        SentryLaunchProfiling.configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(SentryLaunchProfiling.launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchContinuousProfileV2ManualLifecycleNotStoppedOnFullyDisplayed() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .manual
        }
        sentry_configureContinuousProfiling(fixture.options)
        SentryLaunchProfiling.configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(SentryLaunchProfiling.launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchContinuousProfileV2TraceLifecycleNotStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // Arrange
        fixture.options.tracesSampleRate = 1
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options)
        SentryLaunchProfiling.configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(SentryLaunchProfiling.launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchContinuousProfileV2ManualLifecycleNotStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .manual
        }
        sentry_configureContinuousProfiling(fixture.options)
        SentryLaunchProfiling.configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(SentryLaunchProfiling.launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testNonLaunchTracerTransactionCapturedDuringLaunchProfiling() throws {
        // Arrange: set up launch profiling with trace lifecycle
        fixture.options.tracesSampleRate = 1
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options)
        SentryLaunchProfiling.configureLaunchProfilingForNextLaunch(fixture.options)

        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(SentryLaunchProfiling.launchTracer)

        // Act: start and finish a separate transaction during the launch profiling window
        let tracer = try fixture.newTransaction()
        tracer.finish()

        // Assert: the transaction must be captured, not swallowed
        let client = try XCTUnwrap(fixture.client)
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 1)
    }

    func testLaunchTracerTransactionNotCapturedWhenDiscarded() throws {
        // Arrange: set up launch profiling with trace lifecycle
        fixture.options.tracesSampleRate = 1
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options)
        SentryLaunchProfiling.configureLaunchProfilingForNextLaunch(fixture.options)

        SentryLaunchProfiling.startLaunchProfileWithoutDeduplication()
        XCTAssertTrue(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(SentryLaunchProfiling.launchTracer)

        // Act: discard the launch tracer (this is the normal flow)
        SentryLaunchProfiling.stopAndDiscardLaunchProfileTracer(hub: fixture.hub)

        // Assert: the launch tracer's transaction must NOT be captured
        let client = try XCTUnwrap(fixture.client)
        XCTAssertEqual(client.captureEventWithScopeInvocations.count, 0)
    }
}
#endif // !os(macOS)
#endif
