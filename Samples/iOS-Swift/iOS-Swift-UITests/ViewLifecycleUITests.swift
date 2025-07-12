import SentrySampleShared
import XCTest

// This is an UI test for a scenario that was previously crashing the SDK (see https://github.com/getsentry/sentry-cocoa/issues/5087 for details).
//
// See ``ViewLifecycleTestViewController`` for details.
class ViewLifecycleUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }

    override func setUp() {
        super.setUp()
        launchApp(args: [
            SentrySDKOverrides.Performance.disableTimeToFullDisplayTracing.rawValue,
            SentrySDKOverrides.Performance.disablePerformanceV2.rawValue,
            SentrySDKOverrides.Performance.disableAppHangTrackingV2.rawValue
        ])
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testViewLifecycle_callingDismissWithLoadView_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-load-view"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewDidLoad_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-did-load"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewWillAppear_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-will-appear"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewDidAppear_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-did-appear"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewWillDisappear_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-will-disappear"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewDidDisappear_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-did-disappear"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewWillLayoutSubviews_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-will-layout-subviews"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

    func testViewLifecycle_callingDismissWithViewDidLayoutSubviews_shouldNotCrashSDK() {
        // -- Arrange --
        waitForExistenceOfMainScreen()

        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["view-lifecycle-test"].tap()
        app.buttons["dismiss-with-view-did-layout-subviews"].tap()

        // -- Assert --
        // Assert that the app is still running and no crash occurred.
        let isNotCrashed = app.buttons["view-lifecycle-test"].waitForExistence(timeout: 5)
        XCTAssertTrue(isNotCrashed)
    }

}
