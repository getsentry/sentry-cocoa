import XCTest

final class UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchAndCaptureError() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["btError"].tap()
    }
}
