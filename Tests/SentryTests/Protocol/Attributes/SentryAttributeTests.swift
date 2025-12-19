@testable import Sentry
import XCTest

final class SentryAttributeTests: XCTestCase {
    
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
        XCTAssertEqual(attribute.type, "integer[]")
        XCTAssertEqual(attribute.value as? [Int], [1, 2, 3])
    }
    
    func testInitializer_DictionaryValue() {
        let attribute = SentryLog.Attribute(value: ["key": "value"])
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("key") == true)
    }
    
    // MARK: - Protocol-Based Conversion Tests
    
    /// Verifies that protocol-based conversion works for String through init(value: Any)
    func testInitializer_ProtocolBasedConversion_String() {
        let stringValue: String = "protocol string"
        let attribute = SentryLog.Attribute(value: stringValue)
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "protocol string")
    }
    
    /// Verifies that protocol-based conversion works for Bool through init(value: Any)
    func testInitializer_ProtocolBasedConversion_Bool() {
        let boolValue: Bool = true
        let attribute = SentryLog.Attribute(value: boolValue)
        XCTAssertEqual(attribute.type, "boolean")
        XCTAssertEqual(attribute.value as? Bool, true)
    }
    
    /// Verifies that protocol-based conversion works for Int through init(value: Any)
    func testInitializer_ProtocolBasedConversion_Int() {
        let intValue: Int = 42
        let attribute = SentryLog.Attribute(value: intValue)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }
    
    /// Verifies that protocol-based conversion works for Double through init(value: Any)
    func testInitializer_ProtocolBasedConversion_Double() {
        let doubleValue: Double = 3.14159
        let attribute = SentryLog.Attribute(value: doubleValue)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    /// Verifies that protocol-based conversion works for Float through init(value: Any)
    func testInitializer_ProtocolBasedConversion_Float() {
        let floatValue: Float = 2.71828
        let attribute = SentryLog.Attribute(value: floatValue)
        XCTAssertEqual(attribute.type, "double")
        let doubleValue = attribute.value as? Double
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(doubleValue!, 2.71828, accuracy: 0.00001)
    }
    
    /// Verifies that protocol-based conversion works for String arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_StringArray() {
        let stringArray: [String] = ["a", "b", "c"]
        let attribute = SentryLog.Attribute(value: stringArray)
        XCTAssertEqual(attribute.type, "string[]")
        XCTAssertEqual(attribute.value as? [String], ["a", "b", "c"])
    }
    
    /// Verifies that protocol-based conversion works for Bool arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_BoolArray() {
        let boolArray: [Bool] = [true, false, true]
        let attribute = SentryLog.Attribute(value: boolArray)
        XCTAssertEqual(attribute.type, "boolean[]")
        XCTAssertEqual(attribute.value as? [Bool], [true, false, true])
    }
    
    /// Verifies that protocol-based conversion works for Int arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_IntArray() {
        let intArray: [Int] = [1, 2, 3]
        let attribute = SentryLog.Attribute(value: intArray)
        XCTAssertEqual(attribute.type, "integer[]")
        XCTAssertEqual(attribute.value as? [Int], [1, 2, 3])
    }
    
    /// Verifies that protocol-based conversion works for Double arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_DoubleArray() {
        let doubleArray: [Double] = [1.1, 2.2, 3.3]
        let attribute = SentryLog.Attribute(value: doubleArray)
        XCTAssertEqual(attribute.type, "double[]")
        XCTAssertEqual(attribute.value as? [Double], [1.1, 2.2, 3.3])
    }
    
    /// Verifies that protocol-based conversion works for Float arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_FloatArray() throws {
        let floatArray: [Float] = [1.1, 2.2, 3.3]
        let attribute = SentryLog.Attribute(value: floatArray)
        XCTAssertEqual(attribute.type, "double[]")
        let doubleArray = try XCTUnwrap(attribute.value as? [Double])
        XCTAssertEqual(doubleArray, [1.1, 2.2, 3.3])
    }
    
    /// Verifies that fallback to string conversion works for unsupported types
    func testInitializer_Fallback_UnsupportedType() {
        struct UnsupportedType {
            let value = "test"
        }
        let unsupported = UnsupportedType()
        let attribute = SentryLog.Attribute(value: unsupported)
        XCTAssertEqual(attribute.type, "string")
        let stringValue = attribute.value as? String
        XCTAssertNotNil(stringValue)
        XCTAssertTrue(stringValue!.contains("UnsupportedType"))
    }
}
