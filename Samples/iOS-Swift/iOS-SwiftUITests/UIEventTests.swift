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


    func testUIEventIgnoreTextFieldChange(){

        app.buttons["Extra"].tap()
        app.buttons["UI event tests"].tap()

        app.textFields["tfTest"].tap()

        let label = app.staticTexts["lbBreadcrumb"]

        //Set the label to have something to compare after.
        //Also test breadcrumb for buttons
        app.buttons["Press me"].tap()

        app.keys["t"].tap()
        app.keys["e"].tap()
        app.keys["s"].tap()
        app.keys["t"].tap()

        XCTAssertEqual(label.label, "pressMe:")
        app/*@START_MENU_TOKEN@*/.buttons["Return"]/*[[".keyboards",".buttons[\"return\"]",".buttons[\"Return\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        XCTAssertEqual(label.label, "textFieldEndChanging:")
    }

    func waitForExistenceOfMainScreen() {
        app.waitForExistence( "Home Screen doesn't exist.")
    }
}
