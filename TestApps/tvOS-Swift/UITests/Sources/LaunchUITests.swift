import XCTest

class LaunchUITests: XCTestCase {
    
    private let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app.launch()
    }
    
    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testLaunch() throws {
        app.buttons["captureMessageButton"].waitForExistence("Home Screen doesn't exist.")
    }
}

extension XCUIElement {

    func waitForExistence(_ message: String) {
        XCTAssertTrue(self.waitForExistence(timeout: TimeInterval(10)), message)
    }
}
