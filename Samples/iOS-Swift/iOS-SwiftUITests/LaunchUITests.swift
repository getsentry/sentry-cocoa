import XCTest

class LaunchUITests: XCTestCase {
    
    private let timeout: TimeInterval = 10
    private let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        
        waitForExistenseOfMainScreen()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        app.terminate()
    }

    func testLoremIpsum() {
        app.buttons["Lorem Ipsum"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: timeout), "Lorem Ipsum not loaded.")
    }
    
    func testNavigationTransaction() {
        app.buttons["Test Navigation Transaction"].tap()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: timeout), "Navigation transaction not loaded.")
                
        assertApp()
        
    }
    
    func testShowNib() {
        app.buttons["Show Nib"].tap()
        XCTAssertTrue(app.buttons["a lonely button"].waitForExistence(timeout: timeout), "Show Nib not loaded.")
    }

    func testShowTableView() {
        app.buttons["Show TableView"].tap()
        
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: timeout), "Show TableView not loaded.")
    }
    
    func testSplitView() {
        /*app.buttons["Show SplitView"].tap()
        
        //Wait the screen to appear
        XCTAssertTrue(app.navigationBars["iOS_Swift.SplitViewSecondary"].buttons["Root ViewController"].waitForExistence(timeout: timeout), "Show TableView not loaded.")
        
        //Wait the transaction to finish
        XCTAssertTrue(app.staticTexts["children: 11"].waitForExistence(timeout: timeout), "Wrong number of children")
          
        //Tap back button
        app.navigationBars["iOS_Swift.SplitViewSecondary"].buttons["Root ViewController"].tap()
        
        XCTAssertTrue(app.navigationBars["Root ViewController"].buttons["Close"].waitForExistence(timeout: timeout), "Show TableView not loaded.")
          
        app.navigationBars["Root ViewController"].buttons["Close"].tap()*/
    }
        
    private func waitForExistenseOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessage"].waitForExistence(timeout: timeout), "Home Screen doesn't exist.")
        
    }
    
    private func assertApp() {
        let confirmation = app.staticTexts["ASSERT_MESSAGE"]
        let errorMessage = app.staticTexts["ASSERT_ERROR"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: timeout), "Assertion Not Found")
        
        XCTAssertTrue(confirmation.label == "ASSERT: SUCCESS", errorMessage.label)
    }
    
}
