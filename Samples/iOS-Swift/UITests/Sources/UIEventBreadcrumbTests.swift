import XCTest

class UIEventBreadcrumbTests: BaseUITest {

    func testNoBreadcrumbForTextFieldEditingChanged() {
        app.buttons["Extra"].tap()
        app.buttons["uiEventTests"].tap()

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
}
