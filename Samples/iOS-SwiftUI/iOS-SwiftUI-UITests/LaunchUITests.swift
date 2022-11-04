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
    
}
