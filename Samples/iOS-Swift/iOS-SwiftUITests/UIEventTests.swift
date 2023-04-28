import XCTest

class UIEventTests: XCTestCase {
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

    func testUIEventIgnoreTextFieldChange() {

        app.buttons["Extra"].tap()
        app.buttons["UI event tests"].tap()

        app.textFields["tfTest"].tap()

        let label = app.staticTexts["lbBreadcrumb"]

        //Set the label to have something to compare after.
        //Also test breadcrumb for buttons
        app.buttons["Press me"].tap()

        app.textFields["tfTest"].typeText("test")

        XCTAssertEqual(label.label, "pressMe:")
        app.textFields["tfTest"].typeText("\n")
        XCTAssertEqual(label.label, "textFieldEndChanging:")
    }

    func waitForExistenceOfMainScreen() {
        app.waitForExistence( "Home Screen doesn't exist.")
    }
}
