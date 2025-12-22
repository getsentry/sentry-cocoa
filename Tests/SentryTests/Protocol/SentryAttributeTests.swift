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
    
    func testEncodeStringArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryLog.Attribute(stringArray: ["hello", "world", "test"])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "string[]")
        let arrayValue = try XCTUnwrap(json["value"] as? [String])
        XCTAssertEqual(arrayValue, ["hello", "world", "test"])
    }
    
    func testEncodeBooleanArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryLog.Attribute(booleanArray: [true, false, true])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "boolean[]")
        let arrayValue = try XCTUnwrap(json["value"] as? [Bool])
        XCTAssertEqual(arrayValue, [true, false, true])
    }
    
    func testEncodeIntegerArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryLog.Attribute(integerArray: [1, 2, 3, 42])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "integer[]")
        let arrayValue = try XCTUnwrap(json["value"] as? [Int])
        XCTAssertEqual(arrayValue, [1, 2, 3, 42])
    }
    
    func testEncodeDoubleArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryLog.Attribute(doubleArray: [1.1, 2.2, 3.14159])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "double[]")
        let arrayValue = try XCTUnwrap(json["value"] as? [Double])
        XCTAssertEqual(arrayValue.count, 3)
        XCTAssertEqual(arrayValue[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[2], 3.14159, accuracy: 0.00001)
    }
    
    func testEncodeFloatArrayAttribute() throws {
        // -- Arrange --
        let attribute = SentryLog.Attribute(floatArray: [Float(1.1), Float(2.2), Float(3.14159)])
        
        // -- Act --
        let data = try JSONEncoder().encode(attribute)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "double[]")
        let arrayValue = try XCTUnwrap(json["value"] as? [Double])
        XCTAssertEqual(arrayValue.count, 3)
        XCTAssertEqual(arrayValue[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[2], 3.14159, accuracy: 0.00001)
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
    
    func testInitializer_StringArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(stringArray: ["hello", "world", "test"])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let arrayValue = attribute.value as? [String]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, ["hello", "world", "test"])
    }
    
    func testInitializer_EmptyStringArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(stringArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let arrayValue = attribute.value as? [String]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_SingleStringArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(stringArray: ["single"])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let arrayValue = attribute.value as? [String]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, ["single"])
    }
    
    func testInitializer_BooleanArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(booleanArray: [true, false, true])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let arrayValue = attribute.value as? [Bool]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [true, false, true])
    }
    
    func testInitializer_EmptyBooleanArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(booleanArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let arrayValue = attribute.value as? [Bool]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_SingleBooleanArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(booleanArray: [false])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let arrayValue = attribute.value as? [Bool]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [false])
    }
    
    func testInitializer_IntegerArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(integerArray: [1, 2, 3, 42])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let arrayValue = attribute.value as? [Int]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [1, 2, 3, 42])
    }
    
    func testInitializer_EmptyIntegerArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(integerArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let arrayValue = attribute.value as? [Int]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_NegativeIntegerArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(integerArray: [-1, -2, 0, 42])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let arrayValue = attribute.value as? [Int]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [-1, -2, 0, 42])
    }
    
    func testInitializer_DoubleArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(doubleArray: [1.1, 2.2, 3.14159])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!.count, 3)
        XCTAssertEqual(arrayValue![0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![2], 3.14159, accuracy: 0.00001)
    }
    
    func testInitializer_EmptyDoubleArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(doubleArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
    }
    
    func testInitializer_NegativeDoubleArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(doubleArray: [-1.5, 0.0, 3.14])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!.count, 3)
        XCTAssertEqual(arrayValue![0], -1.5, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![1], 0.0, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![2], 3.14, accuracy: 0.00001)
    }
    
    func testInitializer_FloatArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(floatArray: [Float(1.1), Float(2.2), Float(3.14159)])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!.count, 3)
        XCTAssertEqual(arrayValue![0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue![2], 3.14159, accuracy: 0.00001)
    }
    
    func testInitializer_EmptyFloatArrayValue() {
        // -- Arrange --
        let attribute = SentryLog.Attribute(floatArray: [])
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let arrayValue = attribute.value as? [Double]
        XCTAssertNotNil(arrayValue)
        XCTAssertEqual(arrayValue!, [])
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
