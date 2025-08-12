@testable import Sentry
import XCTest

class SentryFrameTests: XCTestCase {

    func testSerialize() {
        // Arrange
        let frame = TestData.mainFrame
        
        // Act
        let actual = frame.serialize()
        
        // Assert
        assertFrameSerializationMatches(frame: frame, serialized: actual)
    }
    
    func testSerialize_WithGodotFrame() {
        // Arrange
        let frame = TestData.godotFrame
        
        // Act
        let serialized = frame.serialize()
        
        // Assert
        assertFrameSerializationMatches(frame: frame, serialized: serialized)
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let frame = TestData.mainFrame
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: frame.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Frame?)
        
        // Assert
        assertFrameDecodingMatches(original: frame, decoded: decoded)
    }
    
    func testDecode_WithGodotFrame() throws {
        // Arrange
        let frame = TestData.godotFrame
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: frame.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Frame?)
        
        // Assert
        assertFrameDecodingMatches(original: frame, decoded: decoded)
    }
    
    func testDecode_WithAllPropertiesNil() throws {
        // Arrange
        let frame = Frame()
        let data = try XCTUnwrap(SentrySerialization.data(withJSONObject: frame.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as Frame?)
        
        // Assert
        XCTAssertNil(decoded.symbolAddress)
        XCTAssertNil(decoded.fileName)
        XCTAssertEqual("<redacted>", decoded.function)
        XCTAssertNil(decoded.module)
        XCTAssertNil(decoded.lineNumber)
        XCTAssertNil(decoded.columnNumber)
        XCTAssertNil(decoded.package)
        XCTAssertNil(decoded.imageAddress)
        XCTAssertNil(decoded.instructionAddress)
        XCTAssertNil(decoded.platform)
        XCTAssertNil(decoded.contextLine)
        XCTAssertNil(decoded.preContext)
        XCTAssertNil(decoded.postContext)
        XCTAssertNil(decoded.vars)
        XCTAssertNil(decoded.inApp)
        XCTAssertNil(decoded.stackStart)
    }
    
    func testSerialize_Bools() {
        SentryBooleanSerialization.test(Frame(), property: "inApp", serializedProperty: "in_app")
        SentryBooleanSerialization.test(Frame(), property: "stackStart", serializedProperty: "stack_start")
    }
    
    private func assertFrameSerializationMatches(frame: Frame, serialized: [String: Any]) {
        XCTAssertEqual(frame.symbolAddress, serialized["symbol_addr"] as? String)
        XCTAssertEqual(frame.fileName, serialized["filename"] as? String)
        XCTAssertEqual(frame.function, serialized["function"] as? String)
        XCTAssertEqual(frame.module, serialized["module"] as? String)
        XCTAssertEqual(frame.lineNumber, serialized["lineno"] as? NSNumber)
        XCTAssertEqual(frame.columnNumber, serialized["colno"] as? NSNumber)
        XCTAssertEqual(frame.package, serialized["package"] as? String)
        XCTAssertEqual(frame.imageAddress, serialized["image_addr"] as? String)
        XCTAssertEqual(frame.instructionAddress, serialized["instruction_addr"] as? String)
        XCTAssertEqual(frame.platform, serialized["platform"] as? String)
        XCTAssertEqual(frame.contextLine, serialized["context_line"] as? String)
        XCTAssertEqual(frame.preContext, serialized["pre_context"] as? [String])
        XCTAssertEqual(frame.postContext, serialized["post_context"] as? [String])
        XCTAssertEqual(frame.vars as? [String: AnyHashable], serialized["vars"] as? [String: AnyHashable])
        XCTAssertEqual(frame.inApp, serialized["in_app"] as? NSNumber)
        XCTAssertEqual(frame.stackStart, serialized["stack_start"] as? NSNumber)
    }    
    
    private func assertFrameDecodingMatches(original: Frame, decoded: Frame) {
        XCTAssertEqual(original.symbolAddress, decoded.symbolAddress)
        XCTAssertEqual(original.fileName, decoded.fileName)
        XCTAssertEqual(original.function, decoded.function)
        XCTAssertEqual(original.module, decoded.module)
        XCTAssertEqual(original.lineNumber, decoded.lineNumber)
        XCTAssertEqual(original.columnNumber, decoded.columnNumber)
        XCTAssertEqual(original.package, decoded.package)
        XCTAssertEqual(original.imageAddress, decoded.imageAddress)
        XCTAssertEqual(original.instructionAddress, decoded.instructionAddress)
        XCTAssertEqual(original.platform, decoded.platform)
        XCTAssertEqual(original.contextLine, decoded.contextLine)
        XCTAssertEqual(original.preContext, decoded.preContext)
        XCTAssertEqual(original.postContext, decoded.postContext)
        XCTAssertEqual(original.vars as? [String: AnyHashable], decoded.vars as? [String: AnyHashable])
        XCTAssertEqual(original.inApp, decoded.inApp)
        XCTAssertEqual(original.stackStart, decoded.stackStart)
    }    
}
