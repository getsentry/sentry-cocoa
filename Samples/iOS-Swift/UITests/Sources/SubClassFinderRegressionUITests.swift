import XCTest

/// Regression test for GH-8152 / GH-8548. The gated fixtures in
/// `SubClassFinderRegressionViewController` are compiled into the app and run through the real
/// swizzle path (no `swizzleClassNameExcludes` workaround), so a launch crash (the fix regressing)
/// fails these tests. This is the acceptance gate for deferred first-instantiation swizzling: run on
/// the iOS 16.4 simulator, where the iOS-17-gated fixture is below its gate.
class SubClassFinderRegressionUITests: BaseUITest {

    /// Reaching the home screen proves the SDK enumerated and (attempted to) swizzle the gated
    /// subclasses at launch without realizing any of them below its gate.
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

    /// Regression test for GH-1355 / GH-1361: opening `ConvenienceInitViewController` instantiates a
    /// UIViewController with a convenience + custom designated initializer (no @objc) via its
    /// convenience init. The old init swizzling crashed this shape on iOS 15; deferred
    /// first-instantiation swizzling (GH-8548) must not. Reaching the screen proves no crash.
    func testOpenConvenienceInitRegressionScreen() {
        app.buttons["Extra"].tap()

        let openButton = app.buttons["ConvenienceInit #1355"]
        openButton.waitForExistence("ConvenienceInit regression button not found in Extra tab.")
        openButton.tap()

        let screen = app.staticTexts["convenienceInitScreen"]
        screen.waitForExistence("ConvenienceInit regression screen did not appear.")
    }
}
