import XCTest

class ViewLifecycleUITests: BaseUITest {
    func testViewLifecycle_callingViewDidLoadAfterDismiss_shouldNotCrashSDK() {
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
