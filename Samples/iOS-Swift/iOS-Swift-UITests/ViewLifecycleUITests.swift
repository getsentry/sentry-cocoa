import XCTest

class ViewLifecycleUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }

    override func setUp() {
        super.setUp()
        launchApp(args: [
            "--disable-time-to-full-display-tracing",
            "--disable-performance-v2",
            "--disable-app-hang-tracking-v2"
        ])
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testViewLifecycle_callingViewDidLoadAfterDismiss_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        // This is an UI tests for a scenario that was previously crashing the SDK.
        // See `ViewLifecycleTestViewController` for details.
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 2)
        XCTAssertTrue(isNotCrashed)
    }
}
