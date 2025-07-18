@testable import Sentry
import XCTest

final class SentryLogAttributeTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    func testEncodeStringAttribute() throws {
        let attribute = SentryLog.Attribute.string("test value")
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["value"] as? String, "test value")
    }
    
    func testEncodeBooleanAttribute() throws {
        let attribute = SentryLog.Attribute.boolean(true)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "boolean")
        XCTAssertEqual(json["value"] as? Bool, true)
    }
    
    func testEncodeIntegerAttribute() throws {
        let attribute = SentryLog.Attribute.integer(42)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["value"] as? Int, 42)
    }
    
    func testEncodeDoubleAttribute() throws {
        let attribute = SentryLog.Attribute.double(3.14159)
        
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
        let original = SentryLog.Attribute.string("round trip test")
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? String, original.value as? String)
    }
    
    func testRoundTripBooleanAttribute() throws {
        let original = SentryLog.Attribute.boolean(false)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? Bool, original.value as? Bool)
    }
    
    func testRoundTripIntegerAttribute() throws {
        let original = SentryLog.Attribute.integer(-999)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value as? Int, original.value as? Int)
    }
    
    func testRoundTripDoubleAttribute() throws {
        let original = SentryLog.Attribute.double(-123.456)
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Attribute?)
        
        XCTAssertEqual(decoded.type, original.type)
        let decodedValue = try XCTUnwrap(decoded.value as? Double)
        let originalValue = try XCTUnwrap(original.value as? Double)
        XCTAssertEqual(decodedValue, originalValue, accuracy: 0.00001)
    }
    
    // MARK: - Initializer Tests
    
    func testInitializer_StringValue() {
        let attribute = SentryLog.Attribute(value: "test string")
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "test string")
    }
    
    func testInitializer_EmptyStringValue() {
        let attribute = SentryLog.Attribute(value: "")
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "")
    }
    
    func testInitializer_BooleanValue() {
        let trueAttribute = SentryLog.Attribute(value: true)
        XCTAssertEqual(trueAttribute.type, "boolean")
        XCTAssertEqual(trueAttribute.value as? Bool, true)
        
        let falseAttribute = SentryLog.Attribute(value: false)
        XCTAssertEqual(falseAttribute.type, "boolean")
        XCTAssertEqual(falseAttribute.value as? Bool, false)
    }
    
    func testInitializer_IntegerValue() {
        let attribute = SentryLog.Attribute(value: 42)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }
    
    func testInitializer_ZeroIntegerValue() {
        let attribute = SentryLog.Attribute(value: 0)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 0)
    }
    
    func testInitializer_NegativeIntegerValue() {
        let attribute = SentryLog.Attribute(value: -42)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, -42)
    }
    
    func testInitializer_DoubleValue() {
        let attribute = SentryLog.Attribute(value: 3.14159)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    func testInitializer_ZeroDoubleValue() {
        let attribute = SentryLog.Attribute(value: 0.0)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 0.0)
    }
    
    func testInitializer_NegativeDoubleValue() {
        let attribute = SentryLog.Attribute(value: -3.14)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, -3.14)
    }
    
    func testInitializer_FloatValue() {
        let attribute = SentryLog.Attribute(value: Float(2.71828))
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
    
    // MARK: - CVarArg Tests
    
    func testInitializer_CVarArg_Int8() {
        let value: Int8 = 127
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 127)
    }
    
    func testInitializer_CVarArg_Int16() {
        let value: Int16 = 32_767
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 32_767)
    }
    
    func testInitializer_CVarArg_Int32() {
        let value: Int32 = 2_147_483_647
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 2_147_483_647)
    }
    
    func testInitializer_CVarArg_Int64() {
        let value: Int64 = 9_223_372_036_854_775_807
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, Int(value))
    }
    
    func testInitializer_CVarArg_Int64_ExceedsIntMax() {
        let value: Int64 = Int64.max
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        
        // Result depends on system's Int.max
        if value <= Int.max {
            // Most 64-bit systems: Int64.max fits in Int
            XCTAssertEqual(attribute.type, "integer")
            XCTAssertEqual(attribute.value as? Int, Int(value))
        } else {
            // Some systems where Int64.max exceeds Int.max
            XCTAssertEqual(attribute.type, "string")
            XCTAssertEqual(attribute.value as? String, String(Int64.max))
        }
    }
    
    func testInitializer_CVarArg_Int64_BelowIntMin() {
        let value: Int64 = Int64.min
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        
        // Result depends on system's Int.min
        if value >= Int.min {
            // Most 64-bit systems: Int64.min fits in Int
            XCTAssertEqual(attribute.type, "integer")
            XCTAssertEqual(attribute.value as? Int, Int(value))
        } else {
            // Some systems where Int64.min is below Int.min
            XCTAssertEqual(attribute.type, "string")
            XCTAssertEqual(attribute.value as? String, String(Int64.min))
        }
    }
    
    func testInitializer_CVarArg_UInt8() {
        let value: UInt8 = 255
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 255)
    }
    
    func testInitializer_CVarArg_UInt16() {
        let value: UInt16 = 65_535
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 65_535)
    }
    
    func testInitializer_CVarArg_UInt32() {
        let value: UInt32 = 214_748_364
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 214_748_364)
    }
    
    func testInitializer_CVarArg_UInt64() {
        let value: UInt64 = 1_000
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 1_000)
    }
    
    func testInitializer_CVarArg_UInt32_ExceedsIntMax() {
        // This test is primarily for 32-bit systems where UInt32.max > Int.max
        // On 64-bit systems, UInt32.max fits within Int.max
        let value: UInt32 = UInt32.max
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        
        // Result depends on system's Int.max
        if value <= Int.max {
            // 64-bit system: UInt32.max fits in Int
            XCTAssertEqual(attribute.type, "integer")
            XCTAssertEqual(attribute.value as? Int, Int(value))
        } else {
            // 32-bit system: UInt32.max exceeds Int.max
            XCTAssertEqual(attribute.type, "string")
            XCTAssertEqual(attribute.value as? String, "4294967295")
        }
    }
    
    func testInitializer_CVarArg_UInt64_ExceedsIntMax() {
        let value: UInt64 = UInt64.max
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "18446744073709551615")
    }
    
    func testInitializer_CVarArg_CGFloat() {
        let value: CGFloat = 42.5
        let arg: CVarArg = value
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 42.5)
    }
    
    func testInitializer_CVarArg_NSNumber_Int() {
        let arg: CVarArg = NSNumber(value: 42)
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }
    
    func testInitializer_CVarArg_NSNumber_Double() {
        let arg: CVarArg = NSNumber(value: 3.14159)
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    func testInitializer_CVarArg_NSNumber_Float() throws {
        let value: Float = 3.14159
        let arg: CVarArg = NSNumber(value: value)
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(try XCTUnwrap(attribute.value as? Double), 3.14159, accuracy: 0.001)
    }
    
    func testInitializer_CVarArg_NSNumber_Bool() {
        let arg = NSNumber(value: true)
        let attribute = SentryLog.Attribute(value: arg)
        XCTAssertEqual(attribute.type, "boolean")
        XCTAssertEqual(attribute.value as? Bool, true)
    }
}
