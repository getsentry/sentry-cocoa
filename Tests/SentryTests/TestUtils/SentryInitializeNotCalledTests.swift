import XCTest

class SentryInitializeNotCalledTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testCallInitialized_SetsSentryInitializerCalledToTrue() throws {
        XCTAssertNotNil(SentryInitializeNotCalled())
        XCTAssertTrue(SentryInitializeNotCalled.wasInitializerCalled())
    }
}
