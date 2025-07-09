//swiftlint:disable file_length

@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
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

// MARK: configuration changes between launches (no TTFD combinations, see iOS-only tests)
extension SentryAppStartProfilingConfigurationChangeTests {
    func test_lastLaunch_traceBased_currentLaunch_continuousV1() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = nil

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_currentLaunch_continuousV2_traceLifecycle() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.tracesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_currentLaunch_continuousV2_manualLifecycle() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_currentLaunch_continuousV2_traceLifecycle() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }
        fixture.options.tracesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_currentLaunch_continuousV2_manualLifecycle() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 1
            $0.profileAppStarts = true
        }

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_currentLaunch_traceBased() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_traceLifecycle_currentLaunch_continuousV1() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_manualLifecycle_currentLaunch_continuousV1() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_traceLifecycle_currentLaunch_traceBased() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_manualLifecycle_currentLaunch_traceBased() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}

// MARK: configuration changes between launches (iOS-only)
#if !os(macOS)
extension SentryAppStartProfilingConfigurationChangeTests {
    // starting with trace-based
    func test_lastLaunch_traceBased_noTTFD_currentLaunch_continuousV1_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = nil
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_noTTFD_currentLaunch_continuousV2_traceLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
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
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_noTTFD_currentLaunch_continuousV2_manualLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
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
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_withTTFD_currentLaunch_continuousV1_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration (continuous V1)
        fixture.options.profilesSampleRate = nil  // Enables continuous profiling V1
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started (trace-based from launch config)
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler not stopped initially (waiting for TTFD due to launch config)
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate TTFD using launch tracer (not a new transaction)
        // Since the launch profiler is trace-based, we use the existing launch tracer
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        // Use the launch tracer for TTFD simulation
        let launchTracer = try XCTUnwrap(sentry_launchTracer)
        
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: launchTracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()

        // Assert profile stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_withTTFD_currentLaunch_continuousV2_traceLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
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
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler not stopped (waiting for TTFD)
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate TTFD
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        
        // Use the launch tracer for TTFD simulation
        let launchTracer = try XCTUnwrap(sentry_launchTracer)

        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: launchTracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()

        // Assert profile stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_withTTFD_currentLaunch_continuousV2_manualLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
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
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler not stopped (waiting for TTFD)
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate TTFD
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        let launchTracer = try XCTUnwrap(sentry_launchTracer)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: launchTracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()

        // Assert profile stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_traceBased_withTTFD_currentLaunch_traceBased_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyTracesSampleRate: 1,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler not stopped (waiting for TTFD)
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate TTFD
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        let launchTracer = try XCTUnwrap(sentry_launchTracer)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: launchTracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()

        // Assert profile stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // starting with continuous v1 no TTFD
    func test_lastLaunch_continuousV1_noTTFD_currentLaunch_continuousV1_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_noTTFD_currentLaunch_continuousV2_traceLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_noTTFD_currentLaunch_continuousV2_manualLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // starting with continuous v1 with TTFD
    func test_lastLaunch_continuousV1_withTTFD_currentLaunch_continuousV1_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler not stopped initially, continuous profiler doesn't wait for TTFD
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_withTTFD_currentLaunch_continuousV2_traceLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_withTTFD_currentLaunch_continuousV2_manualLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV1_withTTFD_currentLaunch_traceBased() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfiling: true,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // starting with continuous v2 no TTFD
    func test_lastLaunch_continuousV2_noTTFD_currentLaunch_continuousV1_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_noTTFD_currentLaunch_continuousV2_traceLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_noTTFD_currentLaunch_continuousV2_manualLifecycle_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_noTTFD_currentLaunch_traceBased() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: false
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // starting with continuous v2 with TTFD
    func test_lastLaunch_continuousV2_withTTFD_currentLaunch_continuousV1_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil
        fixture.options.enableTimeToFullDisplayTracing = false

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_withTTFD_currentLaunch_continuousV1_withTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.profilesSampleRate = nil
        fixture.options.enableTimeToFullDisplayTracing = true

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_withTTFD_currentLaunch_continuousV2_traceLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_withTTFD_currentLaunch_continuousV2_manualLifecycle_noTTFD() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.trace.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyTracesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
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

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    func test_lastLaunch_continuousV2_withTTFD_currentLaunch_traceBased() throws {
        // Arrange
        // persisted configuration simulating previous launch
        let configDict: [String: Any] = [
            kSentryLaunchProfileConfigKeyContinuousProfilingV2: true,
            kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle: SentryProfileLifecycle.manual.rawValue,
            kSentryLaunchProfileConfigKeyProfilesSampleRate: 0.5,
            kSentryLaunchProfileConfigKeyProfilesSampleRand: 0.5,
            kSentryLaunchProfileConfigKeyWaitForFullDisplay: true
        ]
        let configURL = launchProfileConfigFileURL()
        try (configDict as NSDictionary).write(to: configURL)

        // new options simulating current launch configuration
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = 1

        // Act: simulate app launch
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert correct type of profile started
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())

        // Act: simulate SDK start
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))

        // Assert profiler stopped
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}
#endif // !os(macOS)

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

//swiftlint:enable file_length
