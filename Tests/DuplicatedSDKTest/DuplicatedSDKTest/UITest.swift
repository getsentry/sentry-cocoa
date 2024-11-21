import XCTest

final class UITestDuplicatedSDK: XCTestCase {

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.staticTexts["TEST_RESULT"].label, "true")
    }
}
