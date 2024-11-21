import XCTest

final class UITest_DuplicatedSDK: XCTestCase {

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.staticTexts["TEST_RESULT"].label, "true")
    }
}
