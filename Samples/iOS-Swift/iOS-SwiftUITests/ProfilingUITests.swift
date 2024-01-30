import XCTest

//swiftlint:disable function_body_length todo

class ProfilingUITests: BaseUITest {    
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    // this will run before the non-async BaseUITest.setUp, so we can bail out before running any of the logic in there
    override func setUp() async throws {
        try await super.setUp()
        try checkOSVersionForProfilingTest()
    }
    
    func testProfiledAppLaunches() throws {
        launchApp()
        
        // First launch enables in-app profiling by setting traces/profiles sample rates to 1 (which is the default configuration in the sample app), but not launch profiling; assert that we did not write a config to allow the next launch to be profiled
        try performAssertions(shouldProfileThisLaunch: false, shouldProfileNextLaunch: false)
        
        // no profiling should be done on this launch; set the option to allow launch profiling for the next launch, keeping the default numerical sampling rates of 1 for traces and profiles
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true)
        
        // this launch should run the profiler, then set the option to allow launch profiling to true, but set the numerical sample rates to 0 so that the next launch should not profile
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true, profilesSampleRate: 0, tracesSampleRate: 0)
        
        // this launch should not run the profiler; configure sampler functions returning 1 and numerical rates set to 0, which should result in a profile being taken as samplers override numerical rates
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true, profilesSampleRate: 0, tracesSampleRate: 0, profilesSamplerValue: 1, tracesSamplerValue: 1)
        
        // this launch has the configuration to run the profiler, but because swizzling is disabled, it will not run due to the ui.load transaction not being allowed to be created but configure it not to run the next launch due to disabling swizzling, which would override the option to enable launch profiling
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true, shouldDisableSwizzling: true)
        
        // this launch should not run the profiler and configure it not to run the next launch due to disabling automatic performance tracking, which would override the option to enable launch profiling
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true, shouldDisableAutoPerformanceTracking: true)
        
        // this launch should not run the profiler and configure it not to run the next launch launch due to disabling UIViewController tracing, which would override the option to enable launch profiling
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true, shouldDisableUIViewControllerTracing: true)
        
        // this launch should not run the profiler and configure it not to run the next launch launch due to disabling tracing, which would override the option to enable launch profiling
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true, shouldDisableTracing: true)
        
        // make sure the profiler respects the last configuration not to run
        try relaunchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldEnableLaunchProfilingOptionForNextLaunch: true)
    }
    
    /**
     * We had a bug where we forgot to install the frames tracker into the profiler, so weren't sending any GPU frame information with profiles. Since it's not possible to enforce such installation via the compiler, we test for the results we expect here, by starting a transaction, triggering an ANR which will cause degraded frame rendering, stop the transaction, and inspect the profile payload.
     */
    func testProfilingGPUInfo() throws {
        app.launchArguments.append("--disable-swizzling") // we're only interested in the manual transaction, the automatic stuff messes up how we try to retrieve the target profile info
        launchApp()
        
        goToTransactions()
        startTransaction()
        
        app.buttons["ANR filling run loop"].afterWaitingForExistence("Couldn't find button to ANR").tap()
        stopTransaction()
    
        goToProfiling()
        retrieveLastProfileData()
        let profileDict = try marshalJSONDictionaryFromApp()
        
        let metrics = try XCTUnwrap(profileDict["measurements"] as? [String: Any])
        // We can only be sure about frozen frames when triggering an ANR.
        // It could be that there is no slow frame for the captured transaction.
        let frozenFrames = try XCTUnwrap(metrics["frozen_frame_renders"] as? [String: Any])
        let frozenFrameValues = try XCTUnwrap(frozenFrames["values"] as? [[String: Any]])
        XCTAssertFalse(frozenFrameValues.isEmpty, "The test triggered an ANR while the transaction is running. There must be at least one frozen frame, but there was none.")
        
        let frameRates = try XCTUnwrap(metrics["screen_frame_rates"] as? [String: Any])
        let frameRateValues = try XCTUnwrap(frameRates["values"] as? [[String: Any]])
        XCTAssertFalse(frameRateValues.isEmpty)
    }
}

extension ProfilingUITests {
    // We don't need to test these on multiple OSes right now, and older versions seem to have issues; older devices or VM images running simulators might just be slower. Latest OS is enough coverage for our needs for now.
    func checkOSVersionForProfilingTest() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("iOS version too old for profiling test.")
        }
    }
    
    enum Error: Swift.Error {
        case missingFile
        case emptyFile
    }
    
    func marshalJSONDictionaryFromApp() throws -> [String: Any] {
        let string = try XCTUnwrap(app.textFields["io.sentry.ui-tests.profile-marshaling-text-field"].afterWaitingForExistence("Couldn't find data marshaling text field.").value as? NSString)
        if string == "<missing>" {
            throw Error.missingFile
        }
        if string == "<empty>" {
            throw Error.emptyFile
        }
        let data = try XCTUnwrap(Data(base64Encoded: string as String))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    
    func checkLaunchProfileMarkerFileExistence() throws -> Bool {
        app.buttons["io.sentry.ui-tests.app-launch-profile-marker-file-button"].afterWaitingForExistence("Couldn't find app launch profile marker file check button").tap()
        let string = try XCTUnwrap(app.textFields["io.sentry.ui-tests.profile-marshaling-text-field"].afterWaitingForExistence("Couldn't find data marshaling text field.").value as? NSString)
        return string == "<exists>"
    }
    
    func goToTransactions() {
        app.tabBars["Tab Bar"].buttons["Transactions"].tap()
    }
    
    func startTransaction() {
        app.buttons["Start transaction (main thread)"].afterWaitingForExistence("Couldn't find button to start transaction").tap()
    }
    
    func stopTransaction() {
        app.buttons["Stop transaction"].afterWaitingForExistence("Couldn't find button to end transaction").tap()
    }
    
    func goToProfiling() {
        app.tabBars["Tab Bar"].buttons["Profiling"].afterWaitingForExistence("Couldn't find profiling tab bar button").tap()
    }
    
    func retrieveLastProfileData() {
        app.buttons["View last profile"].afterWaitingForExistence("Couldn't find button to view last profile").tap()
    }
    
    func retrieveLaunchProfileData() {
        app.buttons["View launch profile"].afterWaitingForExistence("Couldn't find button to view launch profile").tap()
    }

    func assertLaunchProfile() throws {
        retrieveLaunchProfileData()
        
        var lastProfile = try marshalJSONDictionaryFromApp()
        let sampledProfile = try XCTUnwrap(lastProfile["profile"] as? [String: Any])
        let stacks = try XCTUnwrap(sampledProfile["stacks"] as? [[Int]])
        let frames = try XCTUnwrap(sampledProfile["frames"] as? [[String: Any]])
        let functions = stacks.map({ stack in
            stack.map { stackFrame in
                frames[stackFrame]["function"]
            }
        })
        let stack = try XCTUnwrap(functions.first { nextStack in
            let result = nextStack.contains { frame in
                let result = (frame as! String).contains("+[SentryProfiler(SlowLoad) load]")
                return result
            }
            return result
        }).map { any in
            try XCTUnwrap(any as? String)
        }
        
        XCTAssertFalse(stack.contains("main"))
        XCTAssertFalse(stack.contains("UIApplicationMain"))
        XCTAssertFalse(stack.contains("-[UIApplication _run]"))
        
        // ???: can we assert that this stack was on the main thread?
        // TODO: yes! need to correlate the samples.[].stack_id with samples.[].thread_id
    }
     
    /**
     * Performs the various operations for the launch profiler test case:
     * - terminates an existing app session
     * - creates a new one
     * - sets launch args and env vars to set the appropriate `SentryOption` values for the desired behavior
     * - launches the new configured app session
     * - asserts the expected outcomes of the config file and launch profiler
     */
    func relaunchAndConfigureSubsequentLaunches(
        shouldProfileThisLaunch: Bool,
        shouldEnableLaunchProfilingOptionForNextLaunch: Bool,
        profilesSampleRate: Int? = nil,
        tracesSampleRate: Int? = nil,
        profilesSamplerValue: Int? = nil,
        tracesSamplerValue: Int? = nil,
        shouldDisableAutoPerformanceTracking: Bool = false,
        shouldDisableUIViewControllerTracing: Bool = false,
        shouldDisableSwizzling: Bool = false,
        shouldDisableTracing: Bool = false
    ) throws {
        app.terminate()
        app = newAppSession()
                
        if shouldProfileThisLaunch {
            app.launchArguments.append("--io.sentry.slow-load-method")
        }
        if shouldEnableLaunchProfilingOptionForNextLaunch {
            app.launchArguments.append("--profile-app-launches")
        }
        
        var resolvedProfilesSampleRate: Int?
        if let profilesSampleRate = profilesSampleRate {
            app.launchEnvironment["--io.sentry.profilesSampleRate"] = String(profilesSampleRate)
            resolvedProfilesSampleRate = profilesSampleRate
        }
        if let profilesSamplerValue = profilesSamplerValue {
            app.launchEnvironment["--io.sentry.profilesSamplerValue"] = String(profilesSamplerValue)
            resolvedProfilesSampleRate = profilesSamplerValue
        }
        
        var resolvedTracesSampleRate: Int?
        if let tracesSampleRate = tracesSampleRate {
            app.launchEnvironment["--io.sentry.tracesSampleRate"] = String(tracesSampleRate)
            resolvedTracesSampleRate = tracesSampleRate
        }
        if let tracesSamplerValue = tracesSamplerValue {
            app.launchEnvironment["--io.sentry.tracesSamplerValue"] = String(tracesSamplerValue)
            resolvedTracesSampleRate = tracesSamplerValue
        }
        
        if shouldDisableTracing {
            app.launchArguments.append("--disable-tracing")
        }
        if shouldDisableSwizzling {
            app.launchArguments.append("--disable-swizzling")
        }
        if shouldDisableAutoPerformanceTracking {
            app.launchArguments.append("--disable-auto-performance-tracing")
        }
        if shouldDisableUIViewControllerTracing {
            app.launchArguments.append("--disable-uiviewcontroller-tracing")
        }
        
        launchApp()
        
        let sdkOptionsConfigurationAllowsLaunchProfiling = !(shouldDisableTracing || shouldDisableSwizzling || shouldDisableAutoPerformanceTracking || shouldDisableUIViewControllerTracing)
        
        // these tests only set sample rates to 0 or 1, or don't provide an override (and the sample app sets them to 1 by default)
        let sampleRatesAllowLaunchProfiling = (resolvedTracesSampleRate == nil || resolvedTracesSampleRate! == 1) && (resolvedProfilesSampleRate == nil || resolvedProfilesSampleRate == 1)
        
        let shouldProfileNextLaunch = shouldEnableLaunchProfilingOptionForNextLaunch && sdkOptionsConfigurationAllowsLaunchProfiling && sampleRatesAllowLaunchProfiling
        
        try performAssertions(shouldProfileThisLaunch: shouldProfileThisLaunch, shouldProfileNextLaunch: shouldProfileNextLaunch)
    }
    
    func performAssertions(shouldProfileThisLaunch: Bool, shouldProfileNextLaunch: Bool ) throws {
        goToProfiling()
        
        XCTAssertEqual(shouldProfileNextLaunch, try checkLaunchProfileMarkerFileExistence())
        
        if shouldProfileThisLaunch {
            try assertLaunchProfile()
        }
    }
}

//swiftlint:enable function_body_length todo
