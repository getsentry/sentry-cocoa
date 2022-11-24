import XCTest

class SentryBaseUnitTest: XCTestCase {
    override func tearDown() {
        clearTestState()
        super.tearDown()
    }
}
