import SentryTestUtils
import XCTest

class SentryExceptionTests: XCTestCase {

    func testSerialize() {
        let exception = TestData.exception
        
        let actual = exception.serialize()
        
        // Changing the original doesn't modify the serialized
        exception.mechanism?.desc = ""
        exception.stacktrace?.registers = [:]

        let expected = TestData.exception
        XCTAssertEqual(expected.type, actual["type"] as! String)
        XCTAssertEqual(expected.value, actual["value"] as! String)
        
        let mechanism = actual["mechanism"] as! [String: Any]
        XCTAssertEqual(TestData.mechanism.desc, mechanism["description"] as? String)
        
        XCTAssertEqual(expected.module, actual["module"] as? String)
        XCTAssertEqual(expected.threadId, actual["thread_id"] as? NSNumber)
        
        let stacktrace = actual["stacktrace"] as! [String: Any]
        XCTAssertEqual(TestData.stacktrace.registers, stacktrace["registers"] as? [String: String])
    }
}
