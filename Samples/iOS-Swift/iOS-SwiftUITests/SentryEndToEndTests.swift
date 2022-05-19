import XCTest

#if os(iOS)
class SentryEndToEndTests: XCTestCase {
    private let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app.launch()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        app.terminate()
    }
    
    func testTheThing() {

    }
}
#endif // os(iOS)
