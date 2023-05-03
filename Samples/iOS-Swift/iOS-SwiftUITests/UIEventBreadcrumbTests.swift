import XCTest

class UIEventBreadcrumbTests: XCTestCase {
    private let app: XCUIApplication = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchEnvironment["io.sentry.ui-test.test-name"] = name
        app.launch()

        waitForExistenceOfMainScreen()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testNoBreadcrumbForTextFieldEditingChanged() {
        app.buttons["Extra"].tap()
        app.buttons["UI event tests"].tap()

        //Trigger a change in textfield
        app.buttons["editingChangedButton"].tap()

        Thread.sleep(forTimeInterval: 0.5)
        //Check the last breadcrumb is the button being pressed
        XCTAssertEqual(app.staticTexts["breadcrumbLabel"].label, "performEditingChangedPressed:")

        //Trigger an endEditing in textfield
        app.buttons["editingDidEndButton"].tap()
        //Check the last breadcrumb is the endEditing from the textfield and not the button being pressed
        XCTAssertEqual(app.staticTexts["breadcrumbLabel"].label, "textFieldEndChanging:")
    }

    func waitForExistenceOfMainScreen() {
        app.waitForExistence( "Home Screen doesn't exist.")
    }
}
