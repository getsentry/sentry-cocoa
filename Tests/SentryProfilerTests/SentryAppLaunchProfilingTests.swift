import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
final class SentryAppLaunchProfilingSwiftTests: XCTestCase {
    var fixture: SentryProfileTestFixture!
    
    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testContentsOfLaunchTraceProfileTransactionContext() {
        let context = sentry_context(NSNumber(value: 1))
        XCTAssertEqual(context.nameSource.rawValue, 0)
        XCTAssertEqual(context.origin, "auto.app.start.profile")
        XCTAssertEqual(context.sampled, .yes)
    }
    
    #if !os(macOS)
    // test that if a launch continuous profiler is running and SentryTimeToDisplayTracker reports the app is fully drawn, that the profiler continues running
    func testLaunchContinuousProfileNotStoppedOnFullyDisplayed() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.enableContinuousProfiling = true
        sentry_configureLaunchProfiling(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)
        
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(for: UIViewController(nibName: nil, bundle: nil), waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    // test that if a launch trace profiler is running and SentryTimeToDisplayTracker reports the app is fully drawn, that the profile is stopped
    func testLaunchTraceProfileStoppedOnFullyDisplayed() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = 1
        fixture.options.tracesSampleRate = 1
        sentry_configureLaunchProfiling(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())

        let ttd = SentryTimeToDisplayTracker(for: UIViewController(nibName: nil, bundle: nil), waitForFullDisplay: true, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: try XCTUnwrap(sentry_launchTracer))
        ttd.reportInitialDisplay()
        ttd.reportFullyDisplayed()
        fixture.displayLinkWrapper.call()
        XCTAssertFalse(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())
    }
    
    // test that if a launch continuous profiler is running and SentryTimeToDisplayTracker reports the app had its initial frame drawn and isn't waiting for full drawing, that the profiler continues running
    func testLaunchContinuousProfileNotStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.enableContinuousProfiling = true
        sentry_configureLaunchProfiling(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        XCTAssertNil(sentry_launchTracer)
        
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        let tracer = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
        let ttd = SentryTimeToDisplayTracker(for: UIViewController(nibName: nil, bundle: nil), waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: tracer)
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    // test that if a launch trace profiler is running and SentryTimeToDisplayTracker reports the app had its initial frame drawn and isn't waiting for full drawing, that the profile is stopped
    func testLaunchTraceProfileStoppedOnInitialDisplayWithoutWaitingForFullDisplay() throws {
        // start a launch profile
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = 1
        fixture.options.tracesSampleRate = 1
        sentry_configureLaunchProfiling(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())

        let ttd = SentryTimeToDisplayTracker(for: UIViewController(nibName: nil, bundle: nil), waitForFullDisplay: false, dispatchQueueWrapper: fixture.dispatchQueueWrapper)
        ttd.start(for: try XCTUnwrap(sentry_launchTracer))
        ttd.reportInitialDisplay()
        fixture.displayLinkWrapper.call()
        XCTAssertFalse(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())
    }
    #endif // !os(macOS)

    // test that the launch trace instance is nil after stopping the launch
    // profiler
    func testStopLaunchTraceProfile() {
        fixture.options.enableAppLaunchProfiling = true
        fixture.options.profilesSampleRate = 1
        fixture.options.tracesSampleRate = 1
        sentry_configureLaunchProfiling(fixture.options)
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssertNotNil(sentry_launchTracer)
        sentry_manageTraceProfilerOnStartSDK(fixture.options, TestHub(client: nil, andScope: nil))
        XCTAssertNil(sentry_launchTracer)
    }
   
    func testLaunchTraceProfileConfiguration() throws {
        let expectedProfilesSampleRate: NSNumber = 0.567
        let expectedTracesSampleRate: NSNumber = 0.789
        let options = Options()
        options.enableAppLaunchProfiling = true 
        options.profilesSampleRate = expectedProfilesSampleRate
        options.tracesSampleRate = expectedTracesSampleRate
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(appLaunchProfileConfiguration())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyTracesSampleRate], expectedTracesSampleRate)
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyProfilesSampleRate], expectedProfilesSampleRate)
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
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())
        options.profilesSampleRate = 0
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        // ensure we get another config written, to test removal again
        options.profilesSampleRate = 0.567
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())
        options.tracesSampleRate = 0
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssertFalse(appLaunchProfileConfigFileExists())
    }

    // test continuous launch profiling configuration
    func testContinuousLaunchProfileConfiguration() throws {
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.enableContinuousProfiling = true
        
        // sample rates are not considered for continuous profiling
        options.profilesSampleRate = 0
        options.tracesSampleRate = 0
        
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssert(appLaunchProfileConfigFileExists())
        let dict = try XCTUnwrap(appLaunchProfileConfiguration())
        XCTAssertEqual(dict[kSentryLaunchProfileConfigKeyContinuousProfiling], true)

        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    func testTraceProfilerStartsWhenBothSampleRatesAreSet() {
        let options = Options()
        options.enableAppLaunchProfiling = true
        options.profilesSampleRate = 0.567
        options.tracesSampleRate = 0.789
        XCTAssertFalse(appLaunchProfileConfigFileExists())
        sentry_manageTraceProfilerOnStartSDK(options, TestHub(client: nil, andScope: nil))
        XCTAssertTrue(appLaunchProfileConfigFileExists())
        _sentry_nondeduplicated_startLaunchProfile()
        XCTAssert(SentryTraceProfiler.isCurrentlyProfiling())
    }
 
    /**
     * Test how combinations of the following options interact to ultimately decide whether or not to start the profiler on the next app launch..
     * - `enableLaunchProfiling`
     * - `enableTracing`
     * - `enableContinuousProfiling` (always profiles regardless of sample rate or trace options)
     * - `tracesSampleRate`
     * - `profilesSampleRate`
     * - `profilesSampler`
     */
    func testShouldProfileLaunchBasedOnOptionsCombinations() {
        for testCase: (enableAppLaunchProfiling: Bool, enableTracing: Bool, enableContinuousProfiling: Bool, tracesSampleRate: Int, profilesSampleRate: Int, profilesSamplerReturnValue: Int, shouldProfileLaunch: Bool) in [
            // everything false/0
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change profilesSampleRate to 1
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change tracesSampleRate to 1
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change enableContinuousProfiling to true
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change enableTracing to true
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            // change enableAppLaunchProfiling to true
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 0, shouldProfileLaunch: true),
            // change profilesSamplerReturnValue to 1
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: false, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: false, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: false),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: false, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 0, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 0, profilesSamplerReturnValue: 1, shouldProfileLaunch: true),
            (enableAppLaunchProfiling: true, enableTracing: true, enableContinuousProfiling: true, tracesSampleRate: 1, profilesSampleRate: 1, profilesSamplerReturnValue: 1, shouldProfileLaunch: true)
        ] {
            let options = Options()
            options.enableAppLaunchProfiling = testCase.enableAppLaunchProfiling
            options.enableTracing = testCase.enableTracing
            options.enableContinuousProfiling = testCase.enableContinuousProfiling
            options.tracesSampleRate = NSNumber(value: testCase.tracesSampleRate)
            options.profilesSampleRate = NSNumber(value: testCase.profilesSampleRate)
            options.profilesSampler = { _ in
                NSNumber(value: testCase.profilesSamplerReturnValue)
            }
            XCTAssertEqual(sentry_willProfileNextLaunch(options), testCase.shouldProfileLaunch, "Expected \(testCase.shouldProfileLaunch ? "" : "not ")to enable app launch profiling with options: { enableAppLaunchProfiling: \(testCase.enableAppLaunchProfiling), enableTracing: \(testCase.enableTracing), enableContinuousProfiling: \(testCase.enableContinuousProfiling), tracesSampleRate: \(testCase.tracesSampleRate), profilesSampleRate: \(testCase.profilesSampleRate), profilesSamplerReturnValue: \(testCase.profilesSamplerReturnValue) }")
        }
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
