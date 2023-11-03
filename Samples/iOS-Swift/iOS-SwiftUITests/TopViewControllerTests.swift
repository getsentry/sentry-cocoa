import XCTest

class TopViewControllerTests: XCTestCase {
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
    
    func testTabBarViewController() {
        openInspector()
        
        let getTopBT = app.buttons["BTN_TOPVC"]
        getTopBT.waitForExistence("Top VC Button not found.")
        getTopBT.tap()
        
        let lbTopVC = app.staticTexts["LBL_TOPVC"]
        
        XCTAssertEqual(lbTopVC.label, "ExtraViewController")
    }
    
    func testNavigationViewController() {
        openInspector()
        
        app.buttons["Transactions"].tap()
        
        let getTopBT = app.buttons["BTN_TOPVC"]
        getTopBT.waitForExistence("Top VC Button not found.")
        
        let lbTopVC = app.staticTexts["LBL_TOPVC"]
        
        app.buttons["Table Controller"].tap()
        
        getTopBT.tap()
        XCTAssertEqual(lbTopVC.label, "TableViewController")
    }
    
    func testSplitViewController() {
        openInspector()
        
        app.buttons["Transactions"].tap()
        
        let getTopBT = app.buttons["BTN_TOPVC"]
        getTopBT.waitForExistence("Top VC Button not found.")
        
        let lbTopVC = app.staticTexts["LBL_TOPVC"]
        
        app.buttons["Split Controller"].tap()
        
        getTopBT.tap()
        XCTAssertEqual(lbTopVC.label, "SecondarySplitViewController")
    }
    
    func testPagesViewController() {
        openInspector()
        
        app.buttons["Transactions"].tap()
        
        let getTopBT = app.buttons["BTN_TOPVC"]
        getTopBT.waitForExistence("Top VC Button not found.")
        
        let lbTopVC = app.staticTexts["LBL_TOPVC"]
        
        app.buttons["Page Controller"].tap()
        
        getTopBT.tap()
        XCTAssertEqual(lbTopVC.label, "RedViewController")
    }
    
    func openInspector() {
        app.buttons["Extra"].tap()
        app.buttons["TOPVCBTN"].tap()
    }
    
    func waitForExistenceOfMainScreen() {
        app.waitForExistence( "Home Screen doesn't exist.")
    }
}
