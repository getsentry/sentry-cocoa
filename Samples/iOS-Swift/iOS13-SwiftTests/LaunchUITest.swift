import XCTest

class LaunchUITests: XCTestCase {
    
    private let timeout: TimeInterval = 10
    private let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        
        waitForExistenceOfMainScreen()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        app.terminate()
    }
   
    func testShowSwiftUI() {
        app.buttons["Show SwiftUI"].tap()
        XCTAssertTrue(app.staticTexts["SwiftUI!"].waitForExistence(timeout: timeout), "SwiftUI not loaded.")
    }
    
    private func waitForExistenceOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessage"].waitForExistence(timeout: timeout), "Home Screen doesn't exist.")
    }
}
