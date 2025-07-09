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

// MARK: transaction based profiling
extension SentryAppLaunchProfilingTests {
    // test that the launch trace instance is nil after stopping the launch
    // profiler
    func testStopLaunchTraceProfile() {
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = 1
        fixture.options.tracesSampleRate = 1
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssertNotNil(sentry_launchTracer)
        sentry_sdkInitProfilerTasks(fixture.options, TestHub(client: nil, andScope: nil))
        XCTAssertNil(sentry_launchTracer)
    }

    func testLaunchTraceProfileConfiguration() throws {
        // -- Arrange --
        let expectedProfilesSampleRate: NSNumber = 0.567
        let expectedProfilesSampleRand: NSNumber = fixture.fixedRandomValue as NSNumber
        let expectedTracesSampleRate: NSNumber = 0.789
        let expectedTracesSampleRand: NSNumber = fixture.fixedRandomValue as NSNumber

        // -- Act --
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = expectedProfilesSampleRate
        options.tracesSampleRate = expectedTracesSampleRate

        // Smoke test that the file doesn't exist yet
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRate], expectedTracesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRand], expectedTracesSampleRand)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate], expectedProfilesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand], expectedProfilesSampleRand)
    }

    // test that after configuring for a launch profile, a subsequent
    // configuration with insufficient sample rates removes the configuration
    // file
    func testLaunchTraceProfileConfigurationRemoval() {
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = 0.567
        options.tracesSampleRate = 0.789
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())
        options.profilesSampleRate = 0.1 // less than the fixture's "random" value of 0.5
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        // ensure we get another config written, to test removal again
        options.profilesSampleRate = 0.567
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())
        options.tracesSampleRate = 0
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))
        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    func testTraceProfilerStartsWhenBothSampleRatesAreSetAboveZero() {
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = 0.567
        options.tracesSampleRate = 0.789
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))
        XCTAssertTrue(appLaunchProfileConfigFileExists())
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
    }
}

// MARK: transaction based profiling (iOS-only)
#if !os(macOS)
extension SentryAppLaunchProfilingTests {
    // test that if a launch trace profiler is running and SentryTimeToDisplayTracker reports the app had its initial frame drawn and isn't waiting for full drawing, that the profile is stopped
    func testLaunchTraceProfileStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = 1.0
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
        XCTAssert(sentry_isLaunchProfileCorrelatedToTraces())
        XCTAssertNotNil(sentry_launchTracer)

        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)

        // Ensure frames tracker is running (required for TTD tracker)
        SentryDependencyContainer.sharedInstance().framesTracker = fixture.framesTracker

        // Use sentry_launchTracer directly as the parent tracer since your modifications
        // make the performance tracker create child spans (not SentryTracer objects)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        XCTAssertTrue(ttd.start(for: try XCTUnwrap(sentry_launchTracer)))

        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        
        fixture.displayLinkWrapper.call()
        XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
    }

    func testContentsOfLaunchTraceProfileTransactionContext() {
        let context = sentry_contextForLaunchProfilerForTrace(NSNumber(value: 1), NSNumber(value: 1))
        XCTAssertEqual(context.nameSource.rawValue, 0)
        XCTAssertEqual(context.origin, "auto.app.start.profile")
        XCTAssertEqual(context.sampled, .yes)
    }

    // test that if a launch trace profiler is running and SentryTimeToDisplayTracker reports the app is fully drawn, that the profile is stopped
    func testLaunchTraceProfileStoppedOnFullyDisplayed() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = 1
        fixture.options.tracesSampleRate = 1
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())

        SentrySDK.setStart(fixture.options)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: try XCTUnwrap(sentry_launchTracer))
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()
        XCTAssertFalse(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())
    }
}
#endif // !os(macOS)

// MARK: continuous profiling v1
extension SentryAppLaunchProfilingTests {
    func testContinuousLaunchProfileV1Configuration() throws {
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = nil

        // sample rates are not considered for continuous profiling (can't test this with a profilesSampleRate of 0 though, because it must be nil to enable continuous profiling)
        options.tracesSampleRate = 0

        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())

        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfiling], true)

        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // test that after configuring trace based app launch profiling, then on
    // the next launch, configuring profiling for continuous mode, that the
    // configuration file switches from trace-based to continuous-style config
    func testSwitchFromTraceBasedToContinuousLaunchProfileV1Configuration() throws {
        // -- Arrange --
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = 0.567
        options.tracesSampleRate = 0.789

        // Assert:Smoke test that the file doesn't exist
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // -- Act --
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        XCTAssert(appLaunchProfileConfigFileExists())
        var dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRate], options.tracesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRand] as? Double, fixture.fixedRandomValue)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate], options.profilesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand] as? Double, fixture.fixedRandomValue)

        // -- Act --
        options.profilesSampleRate = nil
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfiling], true)
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRand])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand])
    }
}

// MARK: continuous profiling v1 (iOS-only)
#if !os(macOS)
extension SentryAppLaunchProfilingTests {
    // test that if a launch continuous profiler is running and SentryTimeToDisplayTracker reports the app is fully drawn, that the profiler continues running
    func testLaunchContinuousProfileV1NotStoppedOnFullyDisplayed() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = nil
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }

    // test that if a launch continuous profiler is running and SentryTimeToDisplayTracker reports the app had its initial frame drawn and isn't waiting for full drawing, that the profiler continues running
    func testLaunchContinuousProfileV1NotStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = nil
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(name: "UIViewController", waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }
}
#endif // !os(macOS)

// MARK: continuous profiling v2
extension SentryAppLaunchProfilingTests {
    func testContinuousLaunchProfileV2TraceLifecycleConfiguration() throws {
        // Arrange
        let options = Options()
        options.profilesSampleRate = nil
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
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2]), true)
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
        options.profilesSampleRate = nil
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
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2]), true)
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

    func testSwitchFromTraceBasedToContinuousLaunchProfileV2ManualLifecycleConfiguration() throws {
        // -- Arrange --
        let options = Options()
        options.tracesSampleRate = 0.789
        options.profilesSampleRate = 0.567
        options.enableAppLaunchProfiling = true

        // Smoke test that the file doesn't exist
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // -- Act --
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        XCTAssert(appLaunchProfileConfigFileExists())
        var dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRate], options.tracesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRand] as? Double, fixture.fixedRandomValue)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate], options.profilesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand] as? Double, fixture.fixedRandomValue)

        // -- Act --
        options.profilesSampleRate = nil
        options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 0.987
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyContinuousProfiling])
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2], true)
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRand])
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate]).floatValue, 0.987)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand]).floatValue, 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.manual.rawValue)
    }

    func testSwitchFromTraceBasedToContinuousLaunchProfileV2TraceLifecycleConfiguration() throws {
        // -- Arrange --
        let options = Options()
        options.tracesSampleRate = 0.789
        options.profilesSampleRate = 0.567
        options.enableAppLaunchProfiling = true

        // Smoke test that the file doesn't exist
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // -- Act --
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        XCTAssert(appLaunchProfileConfigFileExists())
        var dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRate], options.tracesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRand] as? Double, fixture.fixedRandomValue)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate], options.profilesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand] as? Double, fixture.fixedRandomValue)

        // -- Act --
        options.profilesSampleRate = nil
        options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 0.987
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyContinuousProfiling])
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2], true)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyTracesSampleRate]), 0.789)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyTracesSampleRand]), 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate]).floatValue, 0.987)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand]).floatValue, 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.trace.rawValue)
    }

    func testSwitchFromContinuousLaunchProfileV1ToContinuousLaunchProfileV2ManualLifecycleConfiguration() throws {
        // -- Arrange --
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = 0.567
        options.tracesSampleRate = 0.789

        // -- Assert -- Smoke test that the file doesn't exist
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // -- Act --
        options.profilesSampleRate = nil
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        var dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfiling], true)
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRand])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand])

        // -- Act --
        options.profilesSampleRate = nil
        options.configureProfiling = {
            $0.lifecycle = .manual
            $0.sessionSampleRate = 0.987
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyContinuousProfiling])
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2], true)
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRand])
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate]).floatValue, 0.987)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand]).floatValue, 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.manual.rawValue)
    }

    func testSwitchFromContinuousLaunchProfileV1ToContinuousLaunchProfileV2TraceLifecycleConfiguration() throws {
        // -- Arrange --
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = 0.567
        options.tracesSampleRate = 0.789

        // -- Assert -- Smoke test that the file doesn't exist
        XCTAssertFalse(appLaunchProfileConfigFileExists())

        // -- Act --
        options.profilesSampleRate = nil
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        var dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfiling], true)
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyTracesSampleRand])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate])
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand])

        // -- Act --
        options.profilesSampleRate = nil
        options.tracesSampleRate = 0.789
        options.configureProfiling = {
            $0.lifecycle = .trace
            $0.sessionSampleRate = 0.987
            $0.profileAppStarts = true
        }
        sentry_sdkInitProfilerTasks(options, TestHub(client: nil, andScope: nil))

        // -- Assert --
        dict = try XCTUnwrap(sentry_persistedLaunchProfileConfigurationOptions())
        XCTAssertNil(dict[kSentryLaunchProfileConfigKeyContinuousProfiling])
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2], true)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyTracesSampleRate]), 0.789)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyTracesSampleRand]), 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate]).floatValue, 0.987)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyProfilesSampleRand]).floatValue, 0.5)
        XCTAssertEqual(try XCTUnwrap(dict[kSentryLaunchProfileConfigKeyContinuousProfilingV2Lifecycle]).intValue, SentryProfileLifecycle.trace.rawValue)
    }
}

// MARK: continuous profiling v2 (iOS-only)
#if !os(macOS)
extension SentryAppLaunchProfilingTests {
    func testLaunchContinuousProfileV2TraceLifecycleNotStoppedOnFullyDisplayed() throws {
        // Arrange
        fixture.options.tracesSampleRate = 1
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options)
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(sentry_launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
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
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .manual
        }
        sentry_configureContinuousProfiling(fixture.options)
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
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
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .trace
        }
        sentry_configureContinuousProfiling(fixture.options)
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNotNil(sentry_launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
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
        fixture.options.profilesSampleRate = nil
        fixture.options.configureProfiling = {
            $0.profileAppStarts = true
            $0.sessionSampleRate = 1
            $0.lifecycle = .manual
        }
        sentry_configureContinuousProfiling(fixture.options)
        sentry_configureLaunchProfilingForNextLaunch(fixture.options)

        // Act
        _sentry_nondeduplicated_startLaunchProfile()

        // Assert
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)

        // Act
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
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
