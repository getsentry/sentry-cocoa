import XCTest

class SentryThreadTests: XCTestCase {

    func testSerialize() {
        let thread = TestData.thread
        
        let actual = thread.serialize()
        
        // Changing the original doesn't modify the serialized
        thread.stacktrace = nil
        
        XCTAssertEqual(TestData.thread.threadId, try XCTUnwrap(actual["id"] as? NSNumber))
        XCTAssertFalse(try XCTUnwrap(actual["crashed"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(actual["current"] as? Bool))
        XCTAssertEqual(TestData.thread.name, try XCTUnwrap(actual["name"] as? String))
        XCTAssertNotNil(actual["stacktrace"])
        XCTAssertTrue(try XCTUnwrap(actual["main"] as? Bool))
    }
    
    func testSerialize_ThreadNameNil() {
        let thread = TestData.thread
        thread.name = nil
        
        let actual = thread.serialize()
        
        XCTAssertNil(actual["name"])
    }
    
    func testSerialize_Bools() {
        let thread = SentryThread(threadId: 0)
        
        SentryBooleanSerialization.test(thread, property: "crashed")
        SentryBooleanSerialization.test(thread, property: "current")
        SentryBooleanSerialization.test(thread, property: "isMain", serializedProperty: "main")
    }
}
