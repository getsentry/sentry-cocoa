import XCTest

/// Regression test for GH-8152. The gated fixtures in `SubClassFinderRegressionViewController` are
/// compiled into the app, so a launch crash (the fix regressing) fails these tests.
///
/// The two swizzle-time crasher fixtures are neutralized via `swizzleClassNameExcludes` in the
/// AppDelegate (the documented workaround for the residual crash, GH-8548). To reproduce that
/// residual crash, remove those excludes and run this suite on the iOS 16.4 simulator — that is the
/// acceptance gate for the deferred-swizzling follow-up.
class SubClassFinderRegressionUITests: BaseUITest {

    /// Reaching the home screen proves the SDK walked the gated subclasses without crashing and
    /// that the `swizzleClassNameExcludes` workaround holds.
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
