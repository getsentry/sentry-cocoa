import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        
        func visitScreen(buttonText: String) {
            app.buttons[buttonText].tap()
            app.swipeDown(velocity: .fast)
        }
        
        visitScreen(buttonText: "Lorem Ipsum")
        visitScreen(buttonText: "Test Navigation Transaction")
        visitScreen(buttonText: "Show Nib")
        visitScreen(buttonText: "Show SwiftUI")
    }
}
