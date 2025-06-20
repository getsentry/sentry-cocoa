@testable import Sentry
import XCTest

final class SentryLogAttributeTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    func testEncodeStringAttribute() throws {
        let attribute = SentryLogAttribute.string("test value")
        
        let data = try JSONEncoder().encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "string")
        XCTAssertEqual(json?["value"] as? String, "test value")
    }
    
    func testEncodeBooleanAttribute() throws {
        let attribute = SentryLogAttribute.bool(true)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "boolean")
        XCTAssertEqual(json?["value"] as? Bool, true)
    }
    
    func testEncodeIntegerAttribute() throws {
        let attribute = SentryLogAttribute.int(42)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "integer")
        XCTAssertEqual(json?["value"] as? Int, 42)
    }
    
    func testEncodeDoubleAttribute() throws {
        let attribute = SentryLogAttribute.double(3.14159)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "double")
        XCTAssertEqual(json?["value"] as! Double, 3.14159, accuracy: 0.00001)
    }
    
    func testEncodeWithUnknownType_ThrowsError() {
        let attribute = SentryLogAttribute(value: "test", type: "unknown")
        
        XCTAssertThrowsError(try JSONEncoder().encode(attribute)) { error in
            XCTAssertTrue(error is EncodingError)
            if case let EncodingError.invalidValue(_, context) = error {
                XCTAssertTrue(context.debugDescription.contains("Unknown type: unknown"))
            } else {
                XCTFail("Expected EncodingError.invalidValue")
            }
        }
    }
    
    func testEncodeWithMismatchedTypeAndValue_ThrowsError() {
        let attribute = SentryLogAttribute(value: 42, type: "string")
        
        XCTAssertThrowsError(try JSONEncoder().encode(attribute)) { error in
            XCTAssertTrue(error is EncodingError)
            if case let EncodingError.invalidValue(_, context) = error {
                XCTAssertTrue(context.debugDescription.contains("Unknown type: string"))
            } else {
                XCTFail("Expected EncodingError.invalidValue")
            }
        }
    }
    
    // MARK: - Decoding Tests
    
    func testDecodeStringAttribute() throws {
        let json = Data("""
        {
            "type": "string",
            "value": "decoded value"
        }
        """.utf8)
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLogAttribute?)
        
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "decoded value")
    }
    
    func testDecodeBooleanAttribute() throws {
        let json = Data("""
        {
            "type": "boolean",
            "value": false
        }
        """.utf8)
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLogAttribute?)
        
        XCTAssertEqual(attribute.type, "boolean")
        XCTAssertEqual(attribute.value as? Bool, false)
    }
    
    func testDecodeIntegerAttribute() throws {
        let json = Data("""
        {
            "type": "integer",
            "value": 12345
        }
        """.utf8)
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLogAttribute?)
        
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 12345)
    }
    
    func testDecodeDoubleAttribute() throws {
        let json = Data("""
        {
            "type": "double",
            "value": 2.71828
        }
        """.utf8)
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLogAttribute?)
        
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as! Double, 2.71828, accuracy: 0.00001)
    }
    
    func testDecodeWithUnknownType_ReturnsNil() {
        let json = Data("""
        {
            "type": "unknown",
            "value": "test"
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLogAttribute?
        
        XCTAssertNil(attribute)
    }
    
    func testDecodeWithMissingType_ReturnsNil() {
        let json = Data("""
        {
            "value": "test"
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLogAttribute?
        
        XCTAssertNil(attribute)
    }
    
    func testDecodeWithMissingValue_ReturnsNil() {
        let json = Data("""
        {
            "type": "string"
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLogAttribute?
        
        XCTAssertNil(attribute)
    }
    
    func testDecodeWithWrongValueType_ReturnsNil() {
        let json = Data("""
        {
            "type": "string",
            "value": 42
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLogAttribute?
        
        XCTAssertNil(attribute)
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripStringAttribute() throws {
        let original = SentryLogAttribute.string("round trip test")
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogAttribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? String, original.value as? String)
    }
    
    func testRoundTripBooleanAttribute() throws {
        let original = SentryLogAttribute.bool(false)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogAttribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? Bool, original.value as? Bool)
    }
    
    func testRoundTripIntegerAttribute() throws {
        let original = SentryLogAttribute.int(-999)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogAttribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? Int, original.value as? Int)
    }
    
    func testRoundTripDoubleAttribute() throws {
        let original = SentryLogAttribute.double(-123.456)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogAttribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as! Double, original.value as! Double, accuracy: 0.00001)
    }
}
