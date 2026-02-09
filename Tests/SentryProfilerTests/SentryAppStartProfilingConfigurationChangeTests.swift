// swiftlint:disable file_length

@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS)
/// Validate stopping behavior of launch profiles that run with one set of configured options, where the SDK is started on that launch with a different set of options, to validate that the configured options persisted to disk from the previous launch are the ones used to determine how/when to stop the profiler, and not the new options currently in memory
final class SentryAppStartProfilingConfigurationChangeTests: XCTestCase {
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

#if !os(macOS)
// MARK: configuring launch profiling with TTFD disabled, then launching with it enabled (iOS-only)
extension SentryAppStartProfilingConfigurationChangeTests {
    func test_lastLaunch_continuousV2_manualLifecycle_noTTFD_currentLaunch_continuousV2_traceLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.tracesSampleRate = 1
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate stopping the continuous profiler
        SentrySDK.stopProfiler()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_manualLifecycle_noTTFD_currentLaunch_continuousV2_manualLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate stopping the continuous profiler
        SentrySDK.stopProfiler()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // MARK: starting with continuous v2 trace lifecycle no TTFD
    func test_lastLaunch_continuousV2_traceLifecycle_noTTFD_currentLaunch_continuousV2_traceLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.tracesSampleRate = 1
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate elapsed time to finish UI profile chunk
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_traceLifecycle_noTTFD_currentLaunch_continuousV2_manualLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate elapsed time to finish UI profile chunk
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}

// MARK: configuring launch profiling with TTFD enabled, then launching with it disabled (iOS-only)
extension SentryAppStartProfilingConfigurationChangeTests {
    // MARK: starting with continuous v2 manual lifecycle with TTFD
    func test_lastLaunch_continuousV2_manualLifecycle_withTTFD_currentLaunch_continuousV2_traceLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.tracesSampleRate = 1
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate elapsed time to finish UI profile chunk
        SentrySDK.stopProfiler()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_manualLifecycle_withTTFD_currentLaunch_continuousV2_manualLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate elapsed time to finish UI profile chunk
        SentrySDK.stopProfiler()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // MARK: starting with continuous v2 trace lifecycle with TTFD
    func test_lastLaunch_continuousV2_traceLifecycle_withTTFD_currentLaunch_continuousV2_traceLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.tracesSampleRate = 1
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))
        
        // Act: simulate TTFD stoppage
        let launchTracer = try XCTUnwrap(sentry_launchTracer)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: launchTracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_traceLifecycle_withTTFD_currentLaunch_continuousV2_manualLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = try XCTUnwrap(launchProfileConfigFileURL())
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Act: simulate TTFD stoppage
        let launchTracer = try XCTUnwrap(sentry_launchTracer)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: launchTracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()
        fixture.currentDateProvider.advance(by: 60)
        try fixture.timeoutTimerFactory.check()

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}
#endif // !os(macOS)

#endif // os(iOS) || os(macOS)

// swiftlint:enable file_length
