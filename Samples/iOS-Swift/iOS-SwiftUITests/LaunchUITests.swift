import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        super.setUpWithError()
        continueAfterFailure = false
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
    }
}
