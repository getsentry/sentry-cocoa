@testable import Sentry
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
    
    func testSerialize_Bools() {
        SentryBooleanSerialization.test(SentryStacktrace(frames: [], registers: [:]), property: "snapshot")
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let stacktrace = TestData.stacktrace
        let serialized = stacktrace.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: serialized))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryStacktrace?)
        
        // Assert
        XCTAssertEqual(stacktrace.frames.count, decoded.frames.count)
        XCTAssertEqual(stacktrace.registers, decoded.registers)
        XCTAssertEqual(stacktrace.snapshot, decoded.snapshot)
    }
    
    func testDecode_MissingSnapshot() throws {
        // Arrange
        let stacktrace = TestData.stacktrace
        stacktrace.snapshot = nil
        let serialized = stacktrace.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: serialized))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryStacktrace?)
        
        // Assert
        XCTAssertEqual(stacktrace.frames.count, decoded.frames.count)
        XCTAssertEqual(stacktrace.registers, decoded.registers)
        XCTAssertNil(decoded.snapshot)
    }
    
    func testDecode_EmptyFrames() throws {
        // Arrange
        let stacktrace = TestData.stacktrace
        stacktrace.frames = []
        let serialized = stacktrace.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: serialized))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryStacktrace?)
        
        // Assert
        XCTAssertEqual(stacktrace.frames.count, decoded.frames.count)
        XCTAssertEqual(stacktrace.registers, decoded.registers)
        XCTAssertEqual(stacktrace.snapshot, decoded.snapshot)
    }
    
    func testDecode_EmptyRegisters() throws {
        // Arrange
        let stacktrace = TestData.stacktrace
        stacktrace.registers = [:]
        let serialized = stacktrace.serialize()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: serialized))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryStacktrace?)
        
        // Assert
        XCTAssertEqual(stacktrace.frames.count, decoded.frames.count)
        XCTAssertEqual(stacktrace.registers, decoded.registers)
        XCTAssertEqual(stacktrace.snapshot, decoded.snapshot)
    }
}
