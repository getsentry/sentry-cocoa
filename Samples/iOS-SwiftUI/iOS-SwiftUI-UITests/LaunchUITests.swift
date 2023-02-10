import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testTransactionSpan() {
        let app = XCUIApplication()
        app.launch()
        
        let transactionName = app.staticTexts["TRANSACTION_NAME"]
        let transactionId = app.staticTexts["TRANSACTION_ID"]
        if !transactionName.waitForExistence(timeout: 1) {
            XCTFail("Span operation label not found")
        }
        
        let childParentId = app.staticTexts["CHILD_PARENT_SPANID"]
        let childName = app.staticTexts["CHILD_NAME"]
        
        XCTAssertEqual(childName.label, "Child Span")
        XCTAssertEqual(transactionName.label, "Content View Body")
        XCTAssertEqual(childParentId.label, transactionId.label)
    }

    func testNoNewTransactionForSecondCallToBody() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Form Screen"].tap()

        XCTAssertNotEqual(app.collectionViews.staticTexts["SPAN_ID"].label,"NO SPAN")
        let formScreenNavigationBar = app.navigationBars["Form Screen"]
        formScreenNavigationBar/*@START_MENU_TOKEN@*/.buttons["Test"]/*[[".otherElements[\"Test\"].buttons[\"Test\"]",".buttons[\"Test\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        XCTAssertEqual(app.collectionViews.staticTexts["SPAN_ID"].label,"NO SPAN")
    }
}
