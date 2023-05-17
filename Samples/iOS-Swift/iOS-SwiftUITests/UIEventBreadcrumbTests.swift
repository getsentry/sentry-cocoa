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
        app.buttons["editingChangedButton"].afterWaitingForExistence("Did not find editingChangedButton").tap()

        //Check the last breadcrumb is the button being pressed
        app.staticTexts["performEditingChangedPressed:"].waitForExistence("performEditingChangedPressed: not called")

        //Trigger an endEditing in textfield
        app.buttons["editingDidEndButton"].tap()
        //Check the last breadcrumb is the endEditing from the textfield and not the button being pressed
        app.staticTexts["textFieldEndChanging:"].waitForExistence("textFieldEndChanging: not called")
    }

    func testExtractInfoFromView() {
        app.buttons["Extra"].tap()
        app.buttons["breadcrumbInfoButton"].tap()
        app.buttons["extractInfoButton"].waitForExistence("Extract Info Button not found")
        app.buttons["extractInfoButton"].tap()

        let info = app.staticTexts["infoLabel"].label

        XCTAssertNotEqual(info, "ERROR")
    }

    func waitForExistenceOfMainScreen() {
        app.waitForExistence( "Home Screen doesn't exist.")
    }
}
