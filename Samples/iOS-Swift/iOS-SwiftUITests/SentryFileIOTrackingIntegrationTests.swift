import XCTest
import Sentry

class SentryFileIOTrackingIntegrationTests: XCTestCase {
    
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
    
    private func waitForExistenseOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessageButton"].waitForExistence(), "Home Screen doesn't exist.")
    }
}
