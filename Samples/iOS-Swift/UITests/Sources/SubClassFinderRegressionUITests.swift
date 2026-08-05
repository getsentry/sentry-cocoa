import XCTest

/// What these actually buy on CI: the fixtures stay reachable, compiled in, and not dead-stripped,
/// and the app still launches with them present. They cannot observe the GH-8152 crash — CI runs
/// iOS 17.5 / 18 / 26, all at or above the fixtures' gates, and `AppDelegate` excludes the gated
/// classes from swizzling anyway. For the crash itself, drop those exclusions and run on iOS 16.4.
class SubClassFinderRegressionUITests: BaseUITest {

    /// Guards the launch path: the finder walks the image at start, so a realization crash would
    /// take the app down before the main screen exists.
    func testAppLaunchesWithoutCrashingOnGatedSubclasses() {
        waitForExistenceOfMainScreen()
    }

    /// Reaching the screen runs `referenceGatedFixturesToPreventDeadStripping`, which is what keeps
    /// the gated classes in the binary for the launch test above.
    func testOpenSubClassFinderRegressionScreen() {
        app.buttons["Extra"].tap()

        let openButton = app.buttons["SubClassFinder #8152"]
        openButton.waitForExistence("SubClassFinder regression button not found in Extra tab.")
        openButton.tap()

        let screen = app.staticTexts["subClassFinderRegressionScreen"]
        screen.waitForExistence("SubClassFinder regression screen did not appear.")
    }

    /// Instantiating the convenience-init fixture doesn't crash. Passes today because no init
    /// swizzling is active; the value is as a tripwire if GH-8548 re-introduces it. (GH-1355)
    func testOpenConvenienceInitRegressionScreen() {
        app.buttons["Extra"].tap()

        let openButton = app.buttons["ConvenienceInit #1355"]
        openButton.waitForExistence("ConvenienceInit regression button not found in Extra tab.")
        openButton.tap()

        let screen = app.staticTexts["convenienceInitScreen"]
        screen.waitForExistence("ConvenienceInit regression screen did not appear.")
    }
}
