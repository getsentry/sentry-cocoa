import XCTest

final class iOS_Swift6UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }


    @MainActor
    func testLauchAndCaptureError() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["btError"].tap()
    }
}
