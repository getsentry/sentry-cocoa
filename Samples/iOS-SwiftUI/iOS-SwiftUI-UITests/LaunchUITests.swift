import XCTest

class LaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        super.setUpWithError()
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }

}
