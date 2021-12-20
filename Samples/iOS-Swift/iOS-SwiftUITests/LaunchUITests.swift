import XCTest

class LaunchUITests: XCTestCase {

    private let app: XCUIApplication = XCUIApplication()

    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        
        waitForExistenseOfMainScreen()
    }
    
    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testLoremIpsum() {
        app.buttons["loremIpsumButton"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(), "Lorem Ipsum not loaded.")
    }
    
    func testNavigationTransaction() {
        app.buttons["testNavigationTransactionButton"].tap()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(), "Navigation transaction not loaded.")
        assertApp()
    }
    
    func testShowNib() {
        app.buttons["showNibButton"].tap()
        XCTAssertTrue(app.buttons["lonelyButton"].waitForExistence(), "Nib ViewController not loaded.")
        assertApp()
    }

    func testShowTableView() {
        app.buttons["showTableViewButton"].tap()
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(), "TableView not loaded.")
        assertApp()
    }
    
    func testSplitView() {
        app.buttons["showSplitViewButton"].tap()
        XCTAssertTrue(app.navigationBars["iOS_Swift.SplitViewSecondary"].buttons["Root ViewController"].waitForExistence(), "SplitView not loaded.")
        
        // This validation is currently not working on iOS 10.
        if #available(iOS 11.0, *) {
            assertApp()
        }
    }
        
    private func waitForExistenseOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessageButton"].waitForExistence(), "Home Screen doesn't exist.")
    }
    
    private func assertApp() {
        let confirmation = app.staticTexts["ASSERT_MESSAGE"]
        let errorMessage = app.staticTexts["ASSERT_ERROR"]
        XCTAssertTrue(confirmation.waitForExistence(), "Assertion Message Not Found")
        
        XCTAssertTrue(confirmation.label == "ASSERT: SUCCESS", errorMessage.label)
    }
    
}

extension XCUIElement {

    @discardableResult
    func waitForExistence() -> Bool {
        self.waitForExistence(timeout: TimeInterval(10))
    }
}
