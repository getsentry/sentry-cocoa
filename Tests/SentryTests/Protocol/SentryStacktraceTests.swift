import XCTest

class SentryStacktraceTests: XCTestCase {

    func testSerialize() {
        let stacktrace = TestData.stacktrace
        
        let actual = stacktrace.serialize()
        
        // Changing the original doesn't modify the serialized
        stacktrace.frames.removeAll()
        stacktrace.registers.removeAll()
        
        let frames = actual["frames"] as? [Any]
        XCTAssertEqual(1, frames?.count)
        XCTAssertEqual(["register": "one"], actual["registers"] as? [String: String])
        XCTAssertEqual(stacktrace.snapshot, actual["snapshot"] as? NSNumber)
    }
    
    func testSerializeNoRegisters() {
        let stacktrace = TestData.stacktrace
        stacktrace.registers = [:]
        let actual = stacktrace.serialize()

        XCTAssertNil(actual["registers"] as? [String: String])
    }
    
    func testSerializeNoFrames() {
        let stacktrace = TestData.stacktrace
        stacktrace.frames = []
        let actual = stacktrace.serialize()
        
        XCTAssertNil(actual["frames"] as? [Any])
    }
}
