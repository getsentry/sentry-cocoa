import XCTest

// If you want to debug this tests, make sure to enable `Debug Executable` in the scheme.
// It is disabled because it would stop the test when crashing the app
final class SwiftUITestSampleUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCrash() throws {
        launchApp()

        app.buttons["Crash"].tap()
        
        launchApp()
        XCTAssertTrue(app.staticTexts["Welcome!"].waitForExistence(timeout: 10), "App did not load properly - Welcome text not found")
    }
    
    private func launchApp() {
        app.activate()
        // Make sure the app is ready before launching it
        XCTAssertTrue(app.staticTexts["Welcome!"].waitForExistence(timeout: 10), "App did not activate properly")

        app.launch()
    }
}
