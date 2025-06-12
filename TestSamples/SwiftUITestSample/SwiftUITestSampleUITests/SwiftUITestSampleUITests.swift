import XCTest

// If you want to debug this tests, make sure to enable `Debug Executable` in the scheme.
// It is disabled because it would stop the test when crashing the app
final class SwiftUITestSampleUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if app.state != .notRunning {
            app.terminate()
        }
        
        // Uninstall the app after every test to make sure we run on a clean state
        app.uninstall()
    }

    @MainActor
    func testCrash() throws {
        launchApp()

        app.buttons["Crash"].tap()
        
        launchApp()
        XCTAssertTrue(app.staticTexts["Welcome!"].exists)
    }

    @MainActor
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
        app.launch()
    }
}
