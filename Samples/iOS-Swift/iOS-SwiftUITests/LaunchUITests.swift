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
        app.buttons["Show SplitView"].tap()
        
        XCTAssertTrue(app.navigationBars["iOS_Swift.SplitViewSecondary"].buttons["Root ViewController"].waitForExistence(timeout: timeout), "Show TableView not loaded.")
          
        app.navigationBars["iOS_Swift.SplitViewSecondary"].buttons["Root ViewController"].tap()
        
        XCTAssertTrue(app.navigationBars["Root ViewController"].buttons["Close"].waitForExistence(timeout: timeout), "Show TableView not loaded.")
          
        app.navigationBars["Root ViewController"].buttons["Close"].tap()
    }
        
    private func waitForExistenseOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessage"].waitForExistence(timeout: timeout), "Home Screen doesn't exist.")
        
    }
    
}
