import XCTest

/// Regression test for GH-8152. The gated fixtures in `SubClassFinderRegressionViewController` are
/// compiled into the app, so a launch crash (the fix regressing) fails these tests.
class SubClassFinderRegressionUITests: BaseUITest {

    /// Reaching the home screen proves the SDK walked the gated subclasses without crashing.
    func testAppLaunchesWithoutCrashingOnGatedSubclasses() {
        waitForExistenceOfMainScreen()
    }

    func testOpenSubClassFinderRegressionScreen() {
        app.buttons["Extra"].tap()

        let openButton = app.buttons["SubClassFinder #8152"]
        openButton.waitForExistence("SubClassFinder regression button not found in Extra tab.")
        openButton.tap()

        let screen = app.staticTexts["subClassFinderRegressionScreen"]
        screen.waitForExistence("SubClassFinder regression screen did not appear.")
    }
}
