@testable import Sentry
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
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let thread = TestData.thread
        let actual = thread.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryThread?)
        
        // Assert
        XCTAssertEqual(thread.threadId, decoded.threadId)
        XCTAssertEqual(thread.name, decoded.name)
        XCTAssertEqual(thread.crashed, decoded.crashed)
        XCTAssertEqual(thread.current, decoded.current)
        XCTAssertEqual(thread.isMain, decoded.isMain)
        
        let decodedStacktrace = try XCTUnwrap(decoded.stacktrace)
        let threadStacktrace = try XCTUnwrap(thread.stacktrace)
        XCTAssertEqual(threadStacktrace.frames.count, decodedStacktrace.frames.count)
        XCTAssertEqual(threadStacktrace.registers, decodedStacktrace.registers)
        XCTAssertEqual(threadStacktrace.snapshot, decodedStacktrace.snapshot)
    }

    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let thread = SentryThread(threadId: 0)
        let actual = thread.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryThread?)
        
        // Assert
        XCTAssertEqual(thread.threadId, decoded.threadId)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.stacktrace)
        XCTAssertNil(decoded.crashed)
        XCTAssertNil(decoded.current)
        XCTAssertNil(decoded.isMain)
    }

    func testDecode_WithWrongThreadId_ReturnsNil () throws {
        // Arrange
        let thread = SentryThread(threadId: 10)
        var actual = thread.serialize()
        actual["id"] = "nil"
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: actual))
        
        // Act & Assert
        XCTAssertNil(decodeFromJSONData(jsonData: data) as SentryThread?)
    }
    
}
