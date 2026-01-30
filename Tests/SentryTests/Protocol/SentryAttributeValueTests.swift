@testable import Sentry
import XCTest

final class SentryAttributeContentTests: XCTestCase {
    
    // MARK: - Type Property Tests
    
    func testType_whenString_shouldReturnString() {
        // -- Arrange --
        let value = SentryAttributeContent.string("test")
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "string")
    }
    
    func testType_whenBoolean_shouldReturnBoolean() {
        // -- Arrange --
        let value = SentryAttributeContent.boolean(true)
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "boolean")
    }
    
    func testType_whenInteger_shouldReturnInteger() {
        // -- Arrange --
        let value = SentryAttributeContent.integer(42)
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "integer")
    }
    
    func testType_whenDouble_shouldReturnDouble() {
        // -- Arrange --
        let value = SentryAttributeContent.double(3.14)
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "double")
    }
    
    func testType_whenStringArray_shouldReturnStringArray() {
        // -- Arrange --
        let value = SentryAttributeContent.stringArray(["a", "b"])
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "array")
    }
    
    func testType_whenBooleanArray_shouldReturnBooleanArray() {
        // -- Arrange --
        let value = SentryAttributeContent.booleanArray([true, false])
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "array")
    }
    
    func testType_whenIntegerArray_shouldReturnIntegerArray() {
        // -- Arrange --
        let value = SentryAttributeContent.integerArray([1, 2])
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "array")
    }
    
    func testType_whenDoubleArray_shouldReturnDoubleArray() {
        // -- Arrange --
        let value = SentryAttributeContent.doubleArray([1.1, 2.2])
        
        // -- Act & Assert --
        XCTAssertEqual(value.type, "array")
    }
    
    // MARK: - Encoding Tests
    
    func testEncode_whenString_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.string("test value")
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "string")
        XCTAssertEqual(json["value"] as? String, "test value")
    }
    
    func testEncode_whenBoolean_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.boolean(true)
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "boolean")
        XCTAssertEqual(json["value"] as? Bool, true)
    }
    
    func testEncode_whenInteger_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.integer(42)
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "integer")
        XCTAssertEqual(json["value"] as? Int, 42)
    }
    
    func testEncode_whenDouble_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.double(3.14159)
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "double")
        let doubleValue = try XCTUnwrap(json["value"] as? Double)
        XCTAssertEqual(doubleValue, 3.14159, accuracy: 0.00001)
    }
    
    func testEncode_whenStringArray_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.stringArray(["hello", "world"])
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [String])
        XCTAssertEqual(arrayValue, ["hello", "world"])
    }
    
    func testEncode_whenBooleanArray_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.booleanArray([true, false, true])
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Bool])
        XCTAssertEqual(arrayValue, [true, false, true])
    }
    
    func testEncode_whenIntegerArray_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.integerArray([1, 2, 3])
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Int])
        XCTAssertEqual(arrayValue, [1, 2, 3])
    }
    
    func testEncode_whenDoubleArray_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeContent.doubleArray([1.1, 2.2, 3.14159])
        
        // -- Act --
        let data = try JSONEncoder().encode(value)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        // -- Assert --
        XCTAssertEqual(json["type"] as? String, "array")
        let arrayValue = try XCTUnwrap(json["value"] as? [Double])
        XCTAssertEqual(arrayValue.count, 3)
        XCTAssertEqual(arrayValue[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[1], 2.2, accuracy: 0.00001)
        XCTAssertEqual(arrayValue[2], 3.14159, accuracy: 0.00001)
    }
    
    // MARK: - from(anyValue:) Tests
    
    func testFromAnyValue_whenString_shouldReturnStringCase() {
        // -- Arrange --
        let input: Any = "test"
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "test")
    }
    
    func testFromAnyValue_whenBool_shouldReturnBooleanCase() {
        // -- Arrange --
        let input: Any = true
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .boolean(let value) = result else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(value, true)
    }
    
    func testFromAnyValue_whenInt_shouldReturnIntegerCase() {
        // -- Arrange --
        let input: Any = 42
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, 42)
    }
    
    func testFromAnyValue_whenDouble_shouldReturnDoubleCase() {
        // -- Arrange --
        let input: Any = 3.14
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(value, 3.14, accuracy: 0.00001)
    }
    
    func testFromAnyValue_whenFloat_shouldReturnDoubleCase() {
        // -- Arrange --
        let input: Any = Float(2.71828)
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .double(let value) = result else {
            return XCTFail("Expected .double case (Float converted to Double)")
        }
        XCTAssertEqual(value, 2.71828, accuracy: 0.00001)
    }
    
    func testFromAnyValue_whenStringArray_shouldReturnStringArrayCase() {
        // -- Arrange --
        let input: Any = ["a", "b", "c"]
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .stringArray(let value) = result else {
            return XCTFail("Expected .stringArray case")
        }
        XCTAssertEqual(value, ["a", "b", "c"])
    }
    
    func testFromAnyValue_whenBooleanArray_shouldReturnBooleanArrayCase() {
        // -- Arrange --
        let input: Any = [true, false]
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .booleanArray(let value) = result else {
            return XCTFail("Expected .booleanArray case")
        }
        XCTAssertEqual(value, [true, false])
    }
    
    func testFromAnyValue_whenIntegerArray_shouldReturnIntegerArrayCase() {
        // -- Arrange --
        let input: Any = [1, 2, 3]
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .integerArray(let value) = result else {
            return XCTFail("Expected .integerArray case")
        }
        XCTAssertEqual(value, [1, 2, 3])
    }
    
    func testFromAnyValue_whenDoubleArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let input: Any = [1.1, 2.2]
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case")
        }
        XCTAssertEqual(value.count, 2)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
    }
    
    func testFromAnyValue_whenFloatArray_shouldReturnDoubleArrayCase() {
        // -- Arrange --
        let input: Any = [Float(1.1), Float(2.2)]
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .doubleArray(let value) = result else {
            return XCTFail("Expected .doubleArray case (Float array converted to Double array)")
        }
        XCTAssertEqual(value.count, 2)
        XCTAssertEqual(value[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(value[1], 2.2, accuracy: 0.00001)
    }
    
    func testFromAnyValue_whenSentryAttributeContent_shouldReturnSameValue() {
        // -- Arrange --
        let input: Any = SentryAttributeContent.string("test")
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "test")
    }
    
    func testFromAnyValue_whenSentryAttributeValue_shouldReturnAttributeContent() {
        // -- Arrange --
        let input: Any = "test" as String
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "test")
    }
    
    func testFromAnyValue_whenSentryAttribute_shouldReturnAttributeValue() {
        // -- Arrange --
        let input: Any = SentryAttribute(string: "test")
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(value, "test")
    }
    
    func testFromAnyValue_whenSentryAttributeWithInteger_shouldReturnIntegerCase() {
        // -- Arrange --
        let input: Any = SentryAttribute(integer: 42)
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .integer(let value) = result else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(value, 42)
    }
    
    func testFromAnyValue_whenSentryAttributeWithBoolean_shouldReturnBooleanCase() {
        // -- Arrange --
        let input: Any = SentryAttribute(boolean: true)
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .boolean(let value) = result else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(value, true)
    }
    
    func testFromAnyValue_whenUnsupportedType_shouldReturnStringCase() {
        // -- Arrange --
        let input: Any = URL(string: "https://example.com")!
        
        // -- Act --
        let result = SentryAttributeContent.from(anyValue: input)
        
        // -- Assert --
        guard case .string(let value) = result else {
            return XCTFail("Expected .string case (fallback for unsupported type)")
        }
        XCTAssertTrue(value.contains("example.com"))
    }
    
    // MARK: - anyValue Tests
    
    func testAnyValue_whenString_shouldReturnStringValue() {
        // -- Arrange --
        let value = SentryAttributeContent.string("test")
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(result as? String, "test")
    }
    
    func testAnyValue_whenBoolean_shouldReturnBooleanValue() {
        // -- Arrange --
        let value = SentryAttributeContent.boolean(true)
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(result as? Bool, true)
    }
    
    func testAnyValue_whenInteger_shouldReturnIntegerValue() {
        // -- Arrange --
        let value = SentryAttributeContent.integer(42)
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(result as? Int, 42)
    }
    
    func testAnyValue_whenDouble_shouldReturnDoubleValue() throws {
        // -- Arrange --
        let value = SentryAttributeContent.double(3.14)
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(result as? Double), 3.14, accuracy: 0.00001)
    }
    
    func testAnyValue_whenStringArray_shouldReturnStringArrayValue() {
        // -- Arrange --
        let value = SentryAttributeContent.stringArray(["a", "b"])
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(result as? [String], ["a", "b"])
    }
    
    func testAnyValue_whenBooleanArray_shouldReturnBooleanArrayValue() {
        // -- Arrange --
        let value = SentryAttributeContent.booleanArray([true, false])
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(result as? [Bool], [true, false])
    }
    
    func testAnyValue_whenIntegerArray_shouldReturnIntegerArrayValue() {
        // -- Arrange --
        let value = SentryAttributeContent.integerArray([1, 2])
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        XCTAssertEqual(result as? [Int], [1, 2])
    }
    
    func testAnyValue_whenDoubleArray_shouldReturnDoubleArrayValue() throws {
        // -- Arrange --
        let value = SentryAttributeContent.doubleArray([1.1, 2.2])
        
        // -- Act --
        let result = value.anyValue
        
        // -- Assert --
        let array = try XCTUnwrap(result as? [Double])
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0], 1.1, accuracy: 0.00001)
        XCTAssertEqual(array[1], 2.2, accuracy: 0.00001)
    }
    
    // MARK: - ExpressibleBy*Literal Tests
    
    func testInit_whenStringLiteral_shouldCreateStringCase() {
        // -- Arrange & Act --
        let value: SentryAttributeContent = "test"
        
        // -- Assert --
        guard case .string(let str) = value else {
            return XCTFail("Expected .string case")
        }
        XCTAssertEqual(str, "test")
    }
    
    func testInit_whenBooleanLiteral_shouldCreateBooleanCase() {
        // -- Arrange & Act --
        let value: SentryAttributeContent = true

        // -- Assert --
        guard case .boolean(let bool) = value else {
            return XCTFail("Expected .boolean case")
        }
        XCTAssertEqual(bool, true)
    }
    
    func testInit_whenIntegerLiteral_shouldCreateIntegerCase() {
        // -- Arrange & Act --
        let value: SentryAttributeContent = 42

        // -- Assert --
        guard case .integer(let int) = value else {
            return XCTFail("Expected .integer case")
        }
        XCTAssertEqual(int, 42)
    }
    
    func testInit_whenFloatLiteral_shouldCreateDoubleCase() {
        // -- Arrange & Act --
        let value: SentryAttributeContent = 3.14
        
        // -- Assert --
        guard case .double(let double) = value else {
            return XCTFail("Expected .double case")
        }
        XCTAssertEqual(double, 3.14, accuracy: 0.00001)
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable_whenSameStringValues_shouldBeEqual() {
        // -- Arrange --
        let value1 = SentryAttributeContent.string("test")
        let value2 = SentryAttributeContent.string("test")
        let value3 = SentryAttributeContent.string("other")
        
        // -- Act & Assert --
        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }
    
    func testEquatable_whenSameStringArrayValues_shouldBeEqual() {
        // -- Arrange --
        let value1 = SentryAttributeContent.stringArray(["a", "b"])
        let value2 = SentryAttributeContent.stringArray(["a", "b"])
        let value3 = SentryAttributeContent.stringArray(["c", "d"])
        
        // -- Act & Assert --
        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }
    
    func testEquatable_whenDifferentTypes_shouldNotBeEqual() {
        // -- Arrange --
        let stringValue = SentryAttributeContent.string("42")
        let intValue = SentryAttributeContent.integer(42)
        
        // -- Act & Assert --
        XCTAssertNotEqual(stringValue, intValue)
    }
}
