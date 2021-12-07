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
        app.buttons["loremIpsumButton"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: timeout), "Lorem Ipsum not loaded.")
    }
    
    func testNavigationTransaction() {
        app.buttons["testNavigationTransactionButton"].tap()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: timeout), "Navigation transaction not loaded.")
        assertApp()
    }
    
    func testShowNib() {
        app.buttons["showNibButton"].tap()
        XCTAssertTrue(app.buttons["a lonely button"].waitForExistence(timeout: timeout), "Nib ViewController not loaded.")
        assertApp()
    }

    func testShowTableView() {
        app.buttons["showTableViewButton"].tap()
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: timeout), "TableView not loaded.")
        assertApp()
    }
    
    func testSplitView() {
        app.buttons["showSplitViewButton"].tap()
        XCTAssertTrue(app.navigationBars["iOS_Swift.SplitViewSecondary"].buttons["Root ViewController"].waitForExistence(timeout: timeout), "SplitView not loaded.")
        
        // This validation is currently not working on iOS 10.
        if #available(iOS 11.0, *) {
            assertApp()
        }
    }
        
    private func waitForExistenseOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessageButton"].waitForExistence(timeout: timeout), "Home Screen doesn't exist.")
    }
    
    private func assertApp() {
        let confirmation = app.staticTexts["ASSERT_MESSAGE"]
        let errorMessage = app.staticTexts["ASSERT_ERROR"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: timeout), "Assertion Message Not Found")
        
        XCTAssertTrue(confirmation.label == "ASSERT: SUCCESS", errorMessage.label)
    }
    
}
