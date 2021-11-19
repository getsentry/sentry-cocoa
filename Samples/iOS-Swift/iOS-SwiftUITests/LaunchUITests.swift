import XCTest

class LaunchUITests: XCTestCase {
    
    private let timeout : TimeInterval = 10

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        
        XCUIDevice.shared.orientation = .portrait
        
        waitForExistenseOfMainScreen()
        
        app.buttons["Test Navigation Transaction"].tap()
        XCTAssertTrue(app.images.firstMatch.waitForExistence(timeout: timeout), "Navigation transaction not loaded.")
        app.swipeDown(velocity: .fast)
        
        waitForExistenseOfMainScreen()
        
        app.buttons["Show Nib"].tap()
        XCTAssertTrue(app.buttons["Button"].waitForExistence(timeout: timeout), "Show Nib not loaded.")
        app.swipeDown(velocity: .fast)
        
        waitForExistenseOfMainScreen()
        
        app.buttons["Show SwiftUI"].tap()
        XCTAssertTrue(app.staticTexts["SwiftUI!"].waitForExistence(timeout: timeout), "SwiftUI not loaded.")
        app.swipeDown(velocity: .fast)
        
        waitForExistenseOfMainScreen()
        
        app.terminate()
        
        func waitForExistenseOfMainScreen() {
            XCTAssertTrue(app.buttons["captureMessage"].waitForExistence(timeout: timeout), "Home Screen doesn't exist.")
        }
    }
}
