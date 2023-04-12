import SentryTestUtils
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
    
    func testSerialize_Bools() {
        let thread = SentryThread(threadId: 0)
        
        SentryBooleanSerialization.test(thread, property: "crashed")
        SentryBooleanSerialization.test(thread, property: "current")
        SentryBooleanSerialization.test(thread, property: "isMain", serializedProperty: "main")
    }
}
