import XCTest

class SentryThreadTests: XCTestCase {

    func testSerialize() {
        let thread = TestData.thread
        
        let actual = thread.serialize()
        
        // Changing the original doesn't modify the serialized
        thread.stacktrace = nil
        
        XCTAssertEqual(TestData.thread.threadId, actual["id"] as! NSNumber)
        XCTAssertFalse(actual["crashed"] as! Bool)
        XCTAssertTrue(actual["current"] as! Bool)
        XCTAssertEqual(TestData.thread.name, actual["name"] as? String)
        XCTAssertNotNil(actual["stacktrace"])
        XCTAssertTrue(actual["main"] as! Bool)
    }
}
