@testable import Sentry
import XCTest

//swiftlint:disable function_body_length todo

class ProfilingUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }
    
    override func setUp() {
        super.setUp()

        app.launchArguments.append(contentsOf: [
            "--io.sentry.wipe-data" // make sure there are no previous configuration files or profile files written
        ])
    }

    func testAppLaunchesWithTraceProfiler() throws {
        guard #available(iOS 16, *) else {
            throw XCTSkip("Only run for latest iOS version we test; we've had issues with prior versions in SauceLabs")
        }

        try performTest(profileType: .trace)
    }
    
    func testAppLaunchesWithContinuousProfilerV1() throws {
        guard #available(iOS 16, *) else {
            throw XCTSkip("Only run for latest iOS version we test; we've had issues with prior versions in SauceLabs")
        }

        try performTest(profileType: .continuous)
    }
    
    func testAppLaunchesWithContinuousProfilerV2TraceLifecycle() throws {
        guard #available(iOS 16, *) else {
            throw XCTSkip("Only run for latest iOS version we test; we've had issues with prior versions in SauceLabs")
        }

        try performTest(profileType: .ui, lifecycle: .trace)
    }
    
    func testAppLaunchesWithContinuousProfilerV2ManualLifeCycle() throws {
        guard #available(iOS 16, *) else {
            throw XCTSkip("Only run for latest iOS version we test; we've had issues with prior versions in SauceLabs")
        }

        try performTest(profileType: .ui, lifecycle: .manual)
    }
    
    /**
     * We had a bug where we forgot to install the frames tracker into the profiler, so weren't sending any GPU frame information with profiles. Since it's not possible to enforce such installation via the compiler, we test for the results we expect here, by starting a transaction, triggering an ANR which will cause degraded frame rendering, stop the transaction, and inspect the profile payload.
     */
    func testProfilingGPUInfo() throws {
        if #available(iOS 16, *) {
            app.launchArguments.append(contentsOf: [
                "--io.sentry.wipe-data",

                // we're only interested in the manual transaction, the automatic stuff messes up how we try to retrieve the target profile info
                "--disable-swizzling",

                "--io.sentry.disable-app-start-profiling"
            ])
            app.launchEnvironment["--io.sentry.profilesSampleRate"] = "1.0"
            launchApp()
            
            goToTransactions()
            startTransaction()
            
            app.buttons["appHangFullyBlocking"].afterWaitingForExistence("Couldn't find button to trigger fully blocking AppHang.").tap()
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
}

extension ProfilingUITests {
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
        app.buttons["startTransactionMainThread"].afterWaitingForExistence("Couldn't find button to start transaction").tap()
    }
    
    func stopTransaction() {
        app.buttons["stopTransaction"].afterWaitingForExistence("Couldn't find button to end transaction").tap()
    }
    
    func goToProfiling() {
        app.tabBars["Tab Bar"].buttons["Profiling"].afterWaitingForExistence("Couldn't find profiling tab bar button").tap()
    }
    
    func retrieveLastProfileData() {
        app.buttons["io.sentry.ui-tests.view-last-profile"].afterWaitingForExistence("Couldn't find button to view last profile").tap()
    }
    
    func retrieveFirstProfileChunkData() {
        app.buttons["io.sentry.ui-tests.view-first-continuous-profile-chunk"].afterWaitingForExistence("Couldn't find button to view first profile chunk").tap()
    }
    
    func stopContinuousProfiler() {
        app.buttons["io.sentry.ios-swift.ui-test.button.stop-continuous-profiler"].afterWaitingForExistence("Couldn't find button to stop continuous profiler").tap()
    }

    enum ProfilingType {
        case trace
        case continuous // aka "continuous beta"
        case ui // aka "continuous v2"
    }

    func performTest(profileType: ProfilingType, lifecycle: SentryProfileOptions.SentryProfileLifecycle? = nil) throws {
        try launchAndConfigureSubsequentLaunches(shouldProfileThisLaunch: false, shouldProfileNextLaunch: true, profileType: profileType, lifecycle: lifecycle)
        try launchAndConfigureSubsequentLaunches(terminatePriorSession: true, shouldProfileThisLaunch: true, shouldProfileNextLaunch: false, profileType: profileType, lifecycle: lifecycle)
    }

    fileprivate func setAppLaunchParameters(_ profileType: ProfilingUITests.ProfilingType, _ lifecycle: SentryProfileOptions.SentryProfileLifecycle?, _ shouldProfileNextLaunch: Bool) {
        app.launchArguments.append(contentsOf: [
            // these help avoid other profiles that'd be taken automatically, that interfere with the checking we do for the assertions later in the tests
            "--disable-swizzling",
            "--disable-auto-performance-tracing",
            "--disable-uiviewcontroller-tracing",
            
            // sets a marker function to run in a load command that the launch profile should detect
            "--io.sentry.slow-load-method",
            
            // override full chunk completion before stoppage introduced in https://github.com/getsentry/sentry-cocoa/pull/4214
            "--io.sentry.continuous-profiler-immediate-stop"
        ])
        
        switch profileType {
        case .ui:
            app.launchEnvironment["--io.sentry.profile-session-sample-rate"] = "1"
            switch lifecycle {
            case .none:
                fatalError("Misconfigured test case. Must provide a lifecycle for UI profiling.")
            case .trace:
                break
            case .manual:
                app.launchArguments.append("--io.sentry.profile-lifecycle-manual")
            }
        case .continuous:
            app.launchArguments.append("--io.sentry.disable-ui-profiling")
        case .trace:
            app.launchEnvironment["--io.sentry.profilesSampleRate"] = "1"
        }
        
        if !shouldProfileNextLaunch {
            app.launchArguments.append("--io.sentry.disable-app-start-profiling")
        }
    }
    
    /**
     * Performs the various operations for the launch profiler test case:
     * - terminates an existing app session
     * - starts a new app session
     * - sets launch args and env vars to set the appropriate `SentryOption` values for the desired behavior
     * - launches the new configured app session, which will optionally start a launch profiler and then call SentrySDK.startWithOptions configured based on the launch args and env vars
     * - asserts the expected outcomes of the config file and launch profiler
     */
    func launchAndConfigureSubsequentLaunches(
        terminatePriorSession: Bool = false,
        shouldProfileThisLaunch: Bool,
        shouldProfileNextLaunch: Bool,
        profileType: ProfilingType,
        lifecycle: SentryProfileOptions.SentryProfileLifecycle?
    ) throws {
        if terminatePriorSession {
            app.terminate()
            app = newAppSession()
        }
        
        setAppLaunchParameters(profileType, lifecycle, shouldProfileNextLaunch)

        launchApp()
        goToProfiling()

        let configFileExists = try checkLaunchProfileMarkerFileExistence()

        if shouldProfileNextLaunch {
            XCTAssert(configFileExists, "A launch profile config file should be present on disk if SentrySDK.startWithOptions configured launch profiling for the next launch.")
        } else {
            XCTAssertFalse(configFileExists, "Launch profile config files should be removed upon starting launch profiles. If SentrySDK.startWithOptions doesn't reconfigure launch profiling, the config file should not be present.")
        }

        guard shouldProfileThisLaunch else {
            return
        }

        if profileType == .trace {
            retrieveLastProfileData()
        } else {
            if profileType == .continuous || (profileType == .ui && lifecycle == .manual) {
                stopContinuousProfiler()
            }
            retrieveFirstProfileChunkData()
        }

        try assertProfileContents()
    }

    func assertProfileContents() throws {
        let lastProfile = try marshalJSONDictionaryFromApp()
        let sampledProfile = try XCTUnwrap(lastProfile["profile"] as? [String: Any])
        let stacks = try XCTUnwrap(sampledProfile["stacks"] as? [[Int]])
        let frames = try XCTUnwrap(sampledProfile["frames"] as? [[String: Any]])
        let stackFunctions = stacks.map({ stack in
            stack.map { stackFrame in
                frames[stackFrame]["function"]
            }
        })

        // grab the first stack that contained frames from the fixture code that simulates a slow +[load] method
        var stackID: Int?
        let stack = try XCTUnwrap(stackFunctions.enumerated().first { nextStack in
            let result = try nextStack.element.contains { frame in
                let found = try XCTUnwrap(frame as? String).contains("+[NSObject(SentryAppSetup) load]")
                if found {
                    stackID = nextStack.offset
                }
                return found
            }
            return result
        }).element.map { any in
            try XCTUnwrap(any as? String)
        }
        guard stackID != nil else {
            XCTFail("Didn't find the ID of the stack containing the target function")
            return
        }

        // ensure that the stack doesn't contain any calls to main functions; this ensures we actually captured pre-main stacks
        XCTAssertFalse(stack.contains("main"))
        XCTAssertFalse(stack.contains("UIApplicationMain"))
        XCTAssertFalse(stack.contains("-[UIApplication _run]"))

        // ensure that the stack happened on the main thread; this is a cross-check to make sure we didn't accidentally grab a stack from a different thread that wouldn't have had a call to main() anyways, thereby possibly missing the real stack that may have contained main() calls (but shouldn't for this test)
        let samples = try XCTUnwrap(sampledProfile["samples"] as? [[String: Any]])
        let sample = try XCTUnwrap(samples.first { nextSample in
            try XCTUnwrap(nextSample["stack_id"] as? NSNumber).intValue == stackID
        })
        XCTAssert(try XCTUnwrap(sample["thread_id"] as? String) == "259") // the main thread is always ID 259
    }
}

//swiftlint:enable function_body_length todo
