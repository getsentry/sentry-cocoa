import XCTest

class TopViewControllerTests: BaseUITest {
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
}
