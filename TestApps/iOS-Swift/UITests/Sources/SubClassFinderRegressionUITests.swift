import XCTest

/// Keeps the fixtures compiled in and the app launchable. These cannot observe the GH-8152 crash:
/// CI runs iOS 17.5 / 18 / 26, all at or above the fixtures' gates, and `AppDelegate` excludes the
/// gated classes from swizzling. For the crash itself, drop those excludes and run on iOS 16.4.
class SubClassFinderRegressionUITests: BaseUITest {

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

    /// Instantiating the convenience-init fixture doesn't crash. (GH-1355)
    func testOpenConvenienceInitRegressionScreen() {
        app.buttons["Extra"].tap()

        let openButton = app.buttons["ConvenienceInit #1355"]
        openButton.waitForExistence("ConvenienceInit regression button not found in Extra tab.")
        openButton.tap()

        let screen = app.staticTexts["convenienceInitScreen"]
        screen.waitForExistence("ConvenienceInit regression screen did not appear.")
    }
}
