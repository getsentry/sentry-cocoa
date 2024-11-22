import XCTest

final class UITestDuplicatedSDK: XCTestCase {

    @MainActor
    func testLoadIntegrations() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.staticTexts["TEST_RESULT"].label, "true", "SentrySDK integrations are not being loaded from the same binary. This will lead to undefined behavior.")
    }
}
