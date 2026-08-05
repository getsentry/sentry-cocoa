import XCTest

/// Keeps the regression fixtures reachable and the app launchable. On CI these run at or above the
/// fixtures' `@available` gates, so they cannot observe the GH-8152 crash — run them on an iOS 16.4
/// simulator for that. (GH-8152)
class SubClassFinderRegressionUITests: BaseUITest {

    /// App launches without realizing a gated subclass below its gate.
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

    /// Opening the convenience-init fixture doesn't crash. (GH-1355)
    func testOpenConvenienceInitRegressionScreen() {
        app.buttons["Extra"].tap()

        let openButton = app.buttons["ConvenienceInit #1355"]
        openButton.waitForExistence("ConvenienceInit regression button not found in Extra tab.")
        openButton.tap()

        let screen = app.staticTexts["convenienceInitScreen"]
        screen.waitForExistence("ConvenienceInit regression screen did not appear.")
    }
}
