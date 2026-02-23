import XCTest

class LaunchUITests: XCTestCase {
    private let timeout: TimeInterval = 10
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        XCUIRemote.shared.press(.down)
  
        let collectionViewsQuery = app.collectionViews
        
        XCTAssert(collectionViewsQuery.children(matching: .cell).element(boundBy: 0).hasFocus)
        
        XCUIRemote.shared.press(.select)
        XCTAssert(app.tables["TABLE_VIEW"].waitForExistence(timeout: timeout))
        XCUIRemote.shared.press(.menu)
        
        XCTAssert(collectionViewsQuery.children(matching: .cell).element(boundBy: 1).waitForExistence(timeout: timeout))
        XCUIRemote.shared.press(.right)
        XCTAssert(collectionViewsQuery.children(matching: .cell).element(boundBy: 1).hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssert(app/*@START_MENU_TOKEN@*/.buttons["LONELY_BUTTON"]/*[[".buttons[\"A lonely button\"]",".buttons[\"LONELY_BUTTON\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.waitForExistence(timeout: timeout))
        XCUIRemote.shared.press(.select)
        XCUIRemote.shared.press(.menu)
        XCTAssert(collectionViewsQuery.children(matching: .cell).element(boundBy: 2).waitForExistence(timeout: timeout))
        XCUIRemote.shared.press(.right)
        XCTAssert(collectionViewsQuery.children(matching: .cell).element(boundBy: 2).hasFocus)
        XCUIRemote.shared.press(.select)
        XCUIRemote.shared.press(.menu)
        
    }
}
