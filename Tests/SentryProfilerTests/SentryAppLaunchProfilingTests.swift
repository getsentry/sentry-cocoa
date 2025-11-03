@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
final class SentryAppLaunchProfilingTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!

    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }

    override func tearDown() {
        super.tearDown()
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
        sentry_sdkInitProfilerTasks(options.toInternal(), TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate]), 1)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand]), 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyTracesSampleRate]), 1)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyTracesSampleRand]), 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.trace.rawValue)

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
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
        sentry_sdkInitProfilerTasks(options.toInternal(), TestHub(client: nil, andScope: nil))

        // Assert
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate]), 1)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand]), 0.5)
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRand])
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.manual.rawValue)

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
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
        sentry_configureContinuousProfiling(fixture.options.toInternal())
        sentry_configureLaunchProfilingForNextLaunch(fixture.options.toInternal())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(sentry_launchTracer)

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
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchContinuousProfileV2ManualLifecycleNotStoppedOnFullyDisplayed() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .manual
        }
        sentry_configureContinuousProfiling(fixture.options.toInternal())
        sentry_configureLaunchProfilingForNextLaunch(fixture.options.toInternal())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

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
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchContinuousProfileV2TraceLifecycleNotStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // Arrange
        fixture.options.tracesSampleRate = 1
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options.toInternal())
        sentry_configureLaunchProfilingForNextLaunch(fixture.options.toInternal())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(sentry_launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func testLaunchContinuousProfileV2ManualLifecycleNotStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // Arrange
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .manual
        }
        sentry_configureContinuousProfiling(fixture.options.toInternal())
        sentry_configureLaunchProfilingForNextLaunch(fixture.options.toInternal())

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}
#endif // !os(macOS)
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
