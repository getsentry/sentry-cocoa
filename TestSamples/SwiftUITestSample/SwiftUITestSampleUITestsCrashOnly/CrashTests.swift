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
        XCTAssertTrue(app.staticTexts["Welcome!"].exists)
    }
    
    private func launchApp() {
        app.activate()
        // Wait for the app to be ready
        sleep(2)
        app.launch()
    }
}
