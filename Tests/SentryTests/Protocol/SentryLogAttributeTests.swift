@testable import Sentry
import XCTest

final class SentryLogAttributeTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    func testEncodeStringAttribute() throws {
        let attribute = SentryLog.Attribute(string: "test value")
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["value"] as? String, "test value")
    }
    
    func testEncodeBooleanAttribute() throws {
        let attribute = SentryLog.Attribute(boolean: true)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "boolean")
        XCTAssertEqual(json["value"] as? Bool, true)
    }
    
    func testEncodeIntegerAttribute() throws {
        let attribute = SentryLog.Attribute(integer: 42)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["value"] as? Int, 42)
    }
    
    func testEncodeDoubleAttribute() throws {
        let attribute = SentryLog.Attribute(double: 3.14159)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "double")
        let doubleValue = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(doubleValue, 3.14159, accuracy: 0.00001)
    }
    
    // MARK: - Decoding Tests
    
    func testDecodeStringAttribute() throws {
        let json = Data("""
        {
            "type": "string",
            "value": "decoded value"
        }
        """.utf8)
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLog.Attribute?)
        
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
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLog.Attribute?)
        
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
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLog.Attribute?)
        
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 12_345)
    }
    
    func testDecodeDoubleAttribute() throws {
        let json = Data("""
        {
            "type": "double",
            "value": 2.71828
        }
        """.utf8)
        
        let attribute = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryLog.Attribute?)
        
        XCTAssertEqual(attribute.type, "double")
        let doubleValue = try XCTUnwrap(attribute.value as? Double)
        XCTAssertEqual(doubleValue, 2.71828, accuracy: 0.00001)
    }
    
    func testDecodeWithUnknownType_ReturnsNil() {
        let json = Data("""
        {
            "type": "unknown",
            "value": "test"
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLog.Attribute?
        
        XCTAssertNil(attribute)
    }
    
    func testDecodeWithMissingType_ReturnsNil() {
        let json = Data("""
        {
            "value": "test"
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLog.Attribute?
        
        XCTAssertNil(attribute)
    }
    
    func testDecodeWithMissingValue_ReturnsNil() {
        let json = Data("""
        {
            "type": "string"
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLog.Attribute?
        
        XCTAssertNil(attribute)
    }
    
    func testDecodeWithWrongValueType_ReturnsNil() {
        let json = Data("""
        {
            "type": "string",
            "value": 42
        }
        """.utf8)
        
        let attribute = decodeFromJSONData(jsonData: json) as SentryLog.Attribute?
        
        XCTAssertNil(attribute)
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripStringAttribute() throws {
        let original = SentryLog.Attribute(string: "round trip test")
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? String, original.value as? String)
    }
    
    func testRoundTripBooleanAttribute() throws {
        let original = SentryLog.Attribute(boolean: false)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? Bool, original.value as? Bool)
    }
    
    func testRoundTripIntegerAttribute() throws {
        let original = SentryLog.Attribute(integer: -999)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? Int, original.value as? Int)
    }
    
    func testRoundTripDoubleAttribute() throws {
        let original = SentryLog.Attribute(double: -123.456)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        let decodedValue = try XCTUnwrap(decoded.value as? Double)
        let originalValue = try XCTUnwrap(original.value as? Double)
        XCTAssertEqual(decodedValue, originalValue, accuracy: 0.00001)
    }
    
    // MARK: - Initializer Tests
    
    func testInitializer_StringValue() {
        let attribute = SentryLog.Attribute(string: "test string")
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "test string")
    }
    
    func testInitializer_EmptyStringValue() {
        let attribute = SentryLog.Attribute(string: "")
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "")
    }
    
    func testInitializer_BooleanValue() {
        let trueAttribute = SentryLog.Attribute(boolean: true)
        XCTAssertEqual(trueAttribute.type, "boolean")
        XCTAssertEqual(trueAttribute.value as? Bool, true)
        
        let falseAttribute = SentryLog.Attribute(boolean: false)
        XCTAssertEqual(falseAttribute.type, "boolean")
        XCTAssertEqual(falseAttribute.value as? Bool, false)
    }
    
    func testInitializer_IntegerValue() {
        let attribute = SentryLog.Attribute(integer: 42)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }
    
    func testInitializer_ZeroIntegerValue() {
        let attribute = SentryLog.Attribute(integer: 0)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 0)
    }
    
    func testInitializer_NegativeIntegerValue() {
        let attribute = SentryLog.Attribute(integer: -42)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, -42)
    }
    
    func testInitializer_DoubleValue() {
        let attribute = SentryLog.Attribute(double: 3.14159)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    func testInitializer_ZeroDoubleValue() {
        let attribute = SentryLog.Attribute(double: 0.0)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 0.0)
    }
    
    func testInitializer_NegativeDoubleValue() {
        let attribute = SentryLog.Attribute(double: -3.14)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, -3.14)
    }
    
    func testInitializer_FloatValue() {
        let attribute = SentryLog.Attribute(float: Float(2.71828))
        XCTAssertEqual(attribute.type, "double")
        let doubleValue = attribute.value as? Double
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(doubleValue!, 2.71828, accuracy: 0.00001)
    }
    
    func testInitializer_NSStringValue() {
        let attribute = SentryLog.Attribute(value: NSString("nsstring test"))
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "nsstring test")
    }
    
    func testInitializer_UnsupportedValue() {
        let url = URL(string: "https://example.com")!
        let attribute = SentryLog.Attribute(value: url)
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("https://example.com") == true)
    }
    
    func testInitializer_ArrayValue() {
        let attribute = SentryLog.Attribute(value: [1, 2, 3])
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("1") == true)
    }
    
    func testInitializer_DictionaryValue() {
        let attribute = SentryLog.Attribute(value: ["key": "value"])
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("key") == true)
    }
}
