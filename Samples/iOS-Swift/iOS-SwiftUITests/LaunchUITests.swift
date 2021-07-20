import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch()  {
        let app = XCUIApplication()
        app.launch()
    }
}
