import SentrySampleShared
import SentrySampleUITestShared
import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testTransactionSpan() {
        let app = newAppSession()
        app.safelyLaunch()

        let transactionName = app.staticTexts["TRANSACTION_NAME"]
        let transactionId = app.staticTexts["TRANSACTION_ID"]
        if !transactionName.waitForExistence(timeout: 5) {
            XCTFail("Span operation label not found")
        }

        let childParentId = app.staticTexts["CHILD_PARENT_SPANID"]
        let childName = app.staticTexts["CHILD_NAME"]

        XCTAssertEqual(childName.label, "Child Span")
        XCTAssertEqual(transactionName.label, "Content View Body")
        XCTAssertEqual(childParentId.label, transactionId.label)
        XCTAssertEqual("auto.ui.swift_ui", app.staticTexts["TRACE_ORIGIN"].label)
        XCTAssertEqual("auto.ui.swift_ui", app.staticTexts["CHILD_TRACE_ORIGIN"].label)
    }

    func testNoNewTransactionForSecondCallToBody() {
        let app = newAppSession()
        app.safelyLaunch()

        app.buttons["Form Screen"].tap()

        XCTAssertNotEqual(app.staticTexts["SPAN_ID"].label, "NO SPAN")
        let formScreenNavigationBar = app.navigationBars["Form Screen"]
        formScreenNavigationBar/*@START_MENU_TOKEN@*/.buttons["Test"]/*[[".otherElements[\"Test\"].buttons[\"Test\"]",".buttons[\"Test\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        XCTAssertEqual(app.staticTexts["SPAN_ID"].label, "NO SPAN")
    }

    func testTTID_TTFD() {
        let app = newAppSession()
        app.safelyLaunch()
        app.buttons["Show TTD"].tap()

        XCTAssertEqual(app.staticTexts["TTDInfo"].label, "TTID and TTFD found")
    }

    func newAppSession() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["--io.sentry.ui-test.test-name"] = name
        app.launchArguments.append(contentsOf: [
            SentrySDKOverrides.Other.disableSpotlight.rawValue,
            SentrySDKOverrides.Special.wipeDataOnLaunch.rawValue
        ])
        return app
    }
}

extension XCUIApplication {
    public func safelyLaunch() {
        // Calling activate() and then launch() effectively launches the app twice, interfering with
        // local debugging. Only call activate if there isn't a debugger attached, which is a decent
        // proxy for whether this is running in CI.
        if !isDebugging() {
            // activate() appears to drop launch args and environment variables, so save them beforehand and reset them before subsequent calls to launch()
            let launchArguments = self.launchArguments
            let launchEnvironment = self.launchEnvironment

            // App prewarming can sometimes cause simulators to get stuck in UI tests, activating them
            // before launching clears any prewarming state.
            activate()

            self.launchArguments = launchArguments
            self.launchEnvironment = launchEnvironment
        }

        launch()
    }
}
