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
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("1") == true)
    }
    
    func testInitializer_DictionaryValue() {
        let attribute = SentryLog.Attribute(value: ["key": "value"])
        XCTAssertEqual(attribute.type, "string")
        XCTAssertTrue((attribute.value as? String)?.contains("key") == true)
    }
    
    // MARK: - Attributable Protocol Tests
    
    func testAttributable_StringConstant() {
        // -- Arrange --
        let endpoint = "api/users"
        
        // -- Act --
        let attribute = endpoint.asAttribute
        
        // -- Assert --
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "api/users")
    }
    
    func testAttributable_BooleanConstant() {
        // -- Arrange --
        let success = true
        let failure = false
        
        // -- Act --
        let successAttr = success.asAttribute
        let failureAttr = failure.asAttribute
        
        // -- Assert --
        XCTAssertEqual(successAttr.type, "boolean")
        XCTAssertEqual(successAttr.value as? Bool, true)
        XCTAssertEqual(failureAttr.type, "boolean")
        XCTAssertEqual(failureAttr.value as? Bool, false)
    }
    
    func testAttributable_IntegerConstant() {
        // -- Arrange --
        let statusCode = 200
        
        // -- Act --
        let attribute = statusCode.asAttribute
        
        // -- Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 200)
    }
    
    func testAttributable_DoubleConstant() {
        // -- Arrange --
        let queryTime = 3.14159
        
        // -- Act --
        let attribute = queryTime.asAttribute
        
        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    func testAttributable_FloatConstant() {
        // -- Arrange --
        let floatValue: Float = 2.71828
        
        // -- Act --
        let attribute = floatValue.asAttribute
        
        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        let doubleValue = attribute.value as? Double
        XCTAssertNotNil(doubleValue)
        XCTAssertEqual(doubleValue!, 2.71828, accuracy: 0.00001)
    }
    
    func testAttributable_SentryAttribute() {
        // -- Arrange --
        let originalAttr = SentryLog.Attribute(string: "test")
        
        // -- Act --
        let convertedAttr = originalAttr.asAttribute
        
        // -- Assert --
        XCTAssertEqual(convertedAttr.type, "string")
        XCTAssertEqual(convertedAttr.value as? String, "test")
        // Should be the same instance
        XCTAssertTrue(convertedAttr === originalAttr)
    }
    
    // MARK: - Expressible By Literal Tests
    
    func testExpressibleByStringLiteral() {
        // -- Arrange --
        let attribute: SentryAttribute = "test literal string"
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "test literal string")
    }
    
    func testExpressibleByStringLiteral_whenEmptyString_shouldCreateStringAttribute() {
        // -- Arrange --
        let attribute: SentryAttribute = ""
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "")
    }
    
    func testExpressibleByBooleanLiteral() {
        // -- Arrange --
        let trueAttribute: SentryAttribute = true
        let falseAttribute: SentryAttribute = false
        
        // -- Act & Assert --
        XCTAssertEqual(trueAttribute.type, "boolean")
        XCTAssertEqual(trueAttribute.value as? Bool, true)
        
        XCTAssertEqual(falseAttribute.type, "boolean")
        XCTAssertEqual(falseAttribute.value as? Bool, false)
    }
    
    func testExpressibleByIntegerLiteral() {
        // -- Arrange --
        let attribute: SentryAttribute = 42
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }
    
    func testExpressibleByIntegerLiteral_whenZero_shouldCreateIntegerAttribute() {
        // -- Arrange --
        let attribute: SentryAttribute = 0
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 0)
    }
    
    func testExpressibleByIntegerLiteral_whenNegative_shouldCreateIntegerAttribute() {
        // -- Arrange --
        let attribute: SentryAttribute = -42
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, -42)
    }
    
    func testExpressibleByFloatLiteral() {
        // -- Arrange --
        let attribute: SentryAttribute = 3.14159
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14159)
    }
    
    func testExpressibleByFloatLiteral_whenZero_shouldCreateDoubleAttribute() {
        // -- Arrange --
        let attribute: SentryAttribute = 0.0
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 0.0)
    }
    
    func testExpressibleByFloatLiteral_whenNegative_shouldCreateDoubleAttribute() {
        // -- Arrange --
        let attribute: SentryAttribute = -3.14
        
        // -- Act & Assert --
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, -3.14)
    }
    
    func testExpressibleByX_inDictionary() {
        // -- Arrange --
        let attributes: [String: SentryAttribute] = [
            "string": "hello",
            "boolean": true,
            "integer": 42,
            "double": 3.14159
        ]
        
        // -- Act & Assert --
        XCTAssertEqual(attributes["string"]?.type, "string")
        XCTAssertEqual(attributes["string"]?.value as? String, "hello")
        
        XCTAssertEqual(attributes["boolean"]?.type, "boolean")
        XCTAssertEqual(attributes["boolean"]?.value as? Bool, true)
        
        XCTAssertEqual(attributes["integer"]?.type, "integer")
        XCTAssertEqual(attributes["integer"]?.value as? Int, 42)
        
        XCTAssertEqual(attributes["double"]?.type, "double")
        XCTAssertEqual(attributes["double"]?.value as? Double, 3.14159)
    }
}
