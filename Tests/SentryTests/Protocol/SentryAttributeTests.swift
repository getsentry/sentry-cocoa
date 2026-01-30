@testable import Sentry
import XCTest

final class SentryAttributeTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    func testEncodeStringAttribute() throws {
        let attribute = SentryAttribute(string: "test value")
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["value"] as? String, "test value")
    }
    
    func testEncodeBooleanAttribute() throws {
        let attribute = SentryAttribute(boolean: true)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "boolean")
        XCTAssertEqual(json["value"] as? Bool, true)
    }
    
    func testEncodeIntegerAttribute() throws {
        let attribute = SentryAttribute(integer: 42)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["value"] as? Int, 42)
    }
    
    func testEncodeDoubleAttribute() throws {
        let attribute = SentryAttribute(double: 3.14159)
        
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(json["type"] as? String, "double")
        let doubleValue = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(doubleValue, 3.14159, accuracy: 0.00001)
    }
    
    func testEncodeStringArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryAttribute(stringArray: ["hello", "world", "test"])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [String])
        XCTAssertEqual(arrayValue, ["hello", "world", "test"])
    }
    
    func testEncodeBooleanArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryAttribute(booleanArray: [true, false, true])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Bool])
        XCTAssertEqual(arrayValue, [true, false, true])
    }
    
    func testEncodeIntegerArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryAttribute(integerArray: [1, 2, 3, 42])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Int])
        XCTAssertEqual(arrayValue, [1, 2, 3, 42])
    }
    
    func testEncodeDoubleArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryAttribute(doubleArray: [1.1, 2.2, 3.14159])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Double])
        XCTAssertEqual(arrayValue.count, 3)
        XCTAssertEqual(arrayValue[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[2], 3.14159, accuracy: 0.00001)
    }
    
    func testEncodeFloatArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryAttribute(floatArray: [Float(1.1), Float(2.2), Float(3.14159)])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Double])
        XCTAssertEqual(arrayValue.count, 3)
        XCTAssertEqual(arrayValue[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[2], 3.14159, accuracy: 0.00001)
    }
    
    // MARK: - Initializer Tests
    
    func testInitializer_StringValue() {
        let attribute = SentryAttribute(string: "test string")
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "test string")
    }
    
    func testInitializer_EmptyStringValue() {
        let attribute = SentryAttribute(string: "")
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
        let attribute = SentryAttribute(integer: 42)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }
    
    func testInitializer_ZeroIntegerValue() {
        let attribute = SentryAttribute(integer: 0)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 0)
    }
    
    func testInitializer_NegativeIntegerValue() {
        let attribute = SentryAttribute(integer: -42)
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, -42)
    }
    
    func testInitializer_DoubleValue() {
        let attribute = SentryAttribute(double: 3.14159)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    func testInitializer_ZeroDoubleValue() {
        let attribute = SentryAttribute(double: 0.0)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 0.0)
    }
    
    func testInitializer_NegativeDoubleValue() {
        let attribute = SentryAttribute(double: -3.14)
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, -3.14)
    }
    
    func testInitializer_FloatValue() {
        let attribute = SentryAttribute(float: Float(2.71828))
        XCTAssertEqual(attribute.type, "double")
        let doubleValue = attribute.value as? Double
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(doubleValue!, 2.71828, accuracy: 0.00001)
    }
    
    func testInitializer_StringArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(stringArray: ["hello", "world", "test"])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [String]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, ["hello", "world", "test"])
    }
    
    func testInitializer_EmptyStringArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(stringArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [String]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_SingleStringArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(stringArray: ["single"])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [String]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, ["single"])
    }
    
    func testInitializer_BooleanArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(booleanArray: [true, false, true])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Bool]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [true, false, true])
    }
    
    func testInitializer_EmptyBooleanArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(booleanArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Bool]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_SingleBooleanArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(booleanArray: [false])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Bool]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [false])
    }
    
    func testInitializer_IntegerArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(integerArray: [1, 2, 3, 42])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Int]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [1, 2, 3, 42])
    }
    
    func testInitializer_EmptyIntegerArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(integerArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Int]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_NegativeIntegerArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(integerArray: [-1, -2, 0, 42])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Int]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [-1, -2, 0, 42])
    }
    
    func testInitializer_DoubleArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(doubleArray: [1.1, 2.2, 3.14159])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!.count, 3)
        XCTAssertEqual(arrayValue![0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![2], 3.14159, accuracy: 0.00001)
    }
    
    func testInitializer_EmptyDoubleArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(doubleArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_NegativeDoubleArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(doubleArray: [-1.5, 0.0, 3.14])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!.count, 3)
        XCTAssertEqual(arrayValue![0], -1.5, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![1], 0.0, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![2], 3.14, accuracy: 0.00001)
    }
    
    func testInitializer_FloatArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(floatArray: [Float(1.1), Float(2.2), Float(3.14159)])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!.count, 3)
        XCTAssertEqual(arrayValue![0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![2], 3.14159, accuracy: 0.00001)
    }
    
    func testInitializer_EmptyFloatArrayValue() {
        // -- Arrange --
        let attribute = SentryAttribute(floatArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "array")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_NSStringValue() {
        let attribute = SentryAttribute(value: NSString("nsstring test"))
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "nsstring test")
    }
    
    func testInitializer_UnsupportedValue() {
        let url = URL(string: "https://example.com")!
        let attribute = SentryAttribute(value: url)
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("https://example.com") == true)
    }
    
    func testInitializer_DictionaryValue() {
        let attribute = SentryAttribute(value: ["key": "value"])
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
        XCTAssertEqual(attribute.type, "array")
        XCTAssertEqual(attribute.value as? [String], ["a", "b", "c"])
    }
    
    /// Verifies that protocol-based conversion works for Bool arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_BoolArray() {
        let boolArray: [Bool] = [true, false, true]
        let attribute = SentryLog.Attribute(value: boolArray)
        XCTAssertEqual(attribute.type, "array")
        XCTAssertEqual(attribute.value as? [Bool], [true, false, true])
    }
    
    /// Verifies that protocol-based conversion works for Int arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_IntArray() {
        let intArray: [Int] = [1, 2, 3]
        let attribute = SentryLog.Attribute(value: intArray)
        XCTAssertEqual(attribute.type, "array")
        XCTAssertEqual(attribute.value as? [Int], [1, 2, 3])
    }
    
    /// Verifies that protocol-based conversion works for Double arrays through init(value: Any)
    func testInitializer_ProtocolBasedConversion_DoubleArray() {
        let doubleArray: [Double] = [1.1, 2.2, 3.3]
        let attribute = SentryLog.Attribute(value: doubleArray)
        XCTAssertEqual(attribute.type, "array")
        XCTAssertEqual(attribute.value as? [Double], [1.1, 2.2, 3.3])
    }
    
    /// Verifies that protocol-based conversion works for Float arrays through init(value: Any)
    ///
    /// Note: Float literals like `1.1`, `2.2`, `3.3` are already approximations in binary representation
    /// (e.g., `Float(1.1)` ≈ `1.100000023841858`). When converting Float arrays to Double arrays,
    /// these approximations are preserved, which is the correct behavior. This is why we use
    /// tolerance-based comparison (`accuracy` parameter) rather than exact equality for floating-point values.
    func testInitializer_ProtocolBasedConversion_FloatArray() throws {
        // -- Arrange --
        let floatArray: [Float] = [1.1, 2.2, 3.3]
        
        // -- Act --
        let attribute = SentryLog.Attribute(value: floatArray)
        
        // -- Assert --
        XCTAssertEqual(attribute.type, "array")
        let doubleArray = try XCTUnwrap(attribute.value as? [Double])
        XCTAssertEqual(doubleArray.count, 3)
        XCTAssertEqual(doubleArray[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(doubleArray[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(doubleArray[2], 3.3, accuracy: 0.00001)
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
