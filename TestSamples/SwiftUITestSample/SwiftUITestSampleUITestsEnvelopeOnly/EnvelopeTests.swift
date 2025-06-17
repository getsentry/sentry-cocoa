import XCTest

final class EnvelopeTest: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCorruptedEnvelope() throws {
        launchApp()
        
        app.buttons["Write Corrupted Envelope"].tap()
        // The close here ensures the next corrupted envelope
        // will be present on the next app launch
        app.buttons["Close SDK"].tap()
        app.buttons["Write Corrupted Envelope"].tap()
        
        app.terminate()
        launchApp()
        XCTAssertTrue(app.staticTexts["Welcome!"].exists)
    }
    
    private func launchApp() {
        app.activate()
        // Wait for the app to be ready
        sleep(2)
        app.launch()
    }
}
