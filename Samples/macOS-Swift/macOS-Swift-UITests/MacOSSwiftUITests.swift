import SentrySampleShared
import XCTest

final class MacOSSwiftUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testMacAppsDontEnableLaunchProfilingForEachOther_Nonsandboxed() throws {
        try performSequence(appBundleID: "io.sentry.macOS-Swift", shouldProfileLaunches: true, wipeData: true, isSandboxed: false)
        try performSequence(appBundleID: "io.sentry.macOS-Swift-Other", shouldProfileLaunches: false, wipeData: false, isSandboxed: false)
    }

    @MainActor
    func testMacAppsDontEnableLaunchProfilingForEachOther_Sandboxed() throws {
        try performSequence(appBundleID: "io.sentry.macOS-Swift-Sandboxed", shouldProfileLaunches: true, wipeData: true, isSandboxed: true)
        try performSequence(appBundleID: "io.sentry.macOS-Swift-Sandboxed-Other", shouldProfileLaunches: false, wipeData: false, isSandboxed: true)
    }
}

private extension MacOSSwiftUITests {
    func performSequence(appBundleID: String, shouldProfileLaunches: Bool, wipeData: Bool, isSandboxed: Bool) throws {
        // one launch to configure launch profiling for the next launch
        let app = XCUIApplication(bundleIdentifier: appBundleID)

        if wipeData {
            app.launchArguments.append("--io.sentry.special.wipe-data")
        }

        try launchAndConfigureSubsequentLaunches(app: app, shouldProfileThisLaunch: false, shouldProfileNextLaunch: shouldProfileLaunches, shouldBeSandboxed: isSandboxed)
        app.terminate()

        if wipeData {
            app.launchArguments.removeAll { $0 == "--io.sentry.special.wipe-data" }
        }

        // second launch to profile a launch if configured
        try launchAndConfigureSubsequentLaunches(app: app, shouldProfileThisLaunch: shouldProfileLaunches, shouldProfileNextLaunch: shouldProfileLaunches, shouldBeSandboxed: isSandboxed)
        app.terminate()
    }

    /**
     * Performs the various operations for the launch profiler test case:
     * - terminates an existing app session
     * - creates a new one
     * - sets launch args and env vars to set the appropriate `SentryOption` values for the desired behavior
     * - verifies that the app sandbox is active or not
     * - launches the new configured app session
     * - asserts the expected outcomes of the config file and launch profiler
     */
    func launchAndConfigureSubsequentLaunches(
        app: XCUIApplication,
        shouldProfileThisLaunch: Bool,
        shouldProfileNextLaunch: Bool,
        shouldBeSandboxed: Bool
    ) throws {
        app.launchArguments.append(contentsOf: [
            // these help avoid other profiles that'd be taken automatically, that interfere with the checking we do for the assertions later in the tests
            SentrySDKOverrides.Other.disableSwizzling.rawValue,
            SentrySDKOverrides.Performance.disablePerformanceTracing.rawValue,
            SentrySDKOverrides.Performance.disableUIVCTracing.rawValue,

            // sets a marker function to run in a load command that the launch profile should detect
            SentrySDKOverrides.Profiling.slowLoadMethod.rawValue,

            // override full chunk completion before stoppage introduced in https://github.com/getsentry/sentry-cocoa/pull/4214
            SentrySDKOverrides.Profiling.immediateStop.rawValue
        ])

        app.launchEnvironment["--io.sentry.ui-test.test-name"] = name

        if !shouldProfileNextLaunch {
            app.launchArguments.append(SentrySDKOverrides.Profiling.disableAppStartProfiling.rawValue)
        }

        app.launch()

        // Make sure we are in the right tab because window restoration can open the previously used app instead.
        // We tried to access the button using a static identifier, but it was not available for lookup.
        returnToMainTab(app: app)

        // Check if the app is sandboxed
        verifyIsSandboxed(app: app, shouldBeSandboxed: shouldBeSandboxed)

        XCTAssertEqual(try checkLaunchProfileMarkerFileExistence(app: app), shouldProfileNextLaunch)

        stopContinuousProfiler(app: app)
        retrieveFirstProfileChunkData(app: app)

        guard let lastProfile = try marshalJSONDictionaryFromApp(app: app, shouldProfile: shouldProfileThisLaunch) else {
            XCTAssertFalse(shouldProfileThisLaunch)
            return
        }

        try assertProfileContents(profile: lastProfile)
    }

    func verifyIsSandboxed(app: XCUIApplication, shouldBeSandboxed: Bool) {
        // Change to the metadata tab to verify checks
        let metadataTabBarButton = app.tabs["Metadata"]
        metadataTabBarButton
            .afterWaitingForExistence("Metadata tab bar button not found")
            .click()

        // Check if the app is sandboxed

        let isSandboxCheckButton = app.checkBoxes["io.sentry.macos-swift.ui-test.checks.app-sandbox.is-active"]
            .afterWaitingForExistence("Couldn't find sandboxed button")
        if shouldBeSandboxed {
            XCTAssertEqual(isSandboxCheckButton.value as? Int, 1, "App Sandbox is not active, but it should be")
        } else {
            XCTAssertEqual(isSandboxCheckButton.value as? Int, 0, "App Sandbox is active, but it shouldn't be")
        }

        returnToMainTab(app: app)
    }

    func returnToMainTab(app: XCUIApplication) {
        let mainTabBarButton = app.tabs["Main"]
        mainTabBarButton
            .afterWaitingForExistence("Main tab bar button not found")
            .click()
    }

    func assertProfileContents(profile: [String: Any]) throws {
        let sampledProfile = try XCTUnwrap(profile["profile"] as? [String: Any])
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

    func retrieveFirstProfileChunkData(app: XCUIApplication) {
        app.buttons["io.sentry.ui-tests.view-first-continuous-profile-chunk"].afterWaitingForExistence("Couldn't find button to view first profile chunk").tap()
    }

    func stopContinuousProfiler(app: XCUIApplication) {
        app.buttons["io.sentry.ios-swift.ui-test.button.stop-continuous-profiler"].afterWaitingForExistence("Couldn't find button to stop continuous profiler").tap()
    }

    func checkLaunchProfileMarkerFileExistence(app: XCUIApplication) throws -> Bool {
        app.buttons["io.sentry.ui-tests.app-launch-profile-marker-file-button"].afterWaitingForExistence("Couldn't find app launch profile marker file check button").tap()
        let string = try XCTUnwrap(app.textFields["io.sentry.ui-tests.profile-marshaling-text-field"].afterWaitingForExistence("Couldn't find data marshaling text field.").value as? NSString)
        return string == "<exists>"
    }

    enum Error: Swift.Error {
        case missingFile
        case emptyFile
    }

    func marshalJSONDictionaryFromApp(app: XCUIApplication, shouldProfile: Bool) throws -> [String: Any]? {
        let string = try XCTUnwrap(app.textFields["io.sentry.ui-tests.profile-marshaling-text-field"].afterWaitingForExistence("Couldn't find data marshaling text field.").value as? NSString)

        if shouldProfile {
            if string == "<missing>" {
                throw Error.missingFile
            }
            if string == "<empty>" {
                throw Error.emptyFile
            }
            let data = try XCTUnwrap(Data(base64Encoded: string as String))
            return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        } else {
            XCTAssertEqual("<missing>", string)
            return nil
        }
    }
}

extension XCUIElement {
    func waitForExistence(_ message: String) {
        XCTAssertTrue(self.waitForExistence(timeout: TimeInterval(10)), message)
    }

    func afterWaitingForExistence(_ failureMessage: String) -> XCUIElement {
        waitForExistence(failureMessage)
        return self
    }
}
