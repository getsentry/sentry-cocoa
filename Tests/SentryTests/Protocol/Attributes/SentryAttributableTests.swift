@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryAttributableTests: XCTestCase {

    // MARK: - String Attributable Tests

    func testasSentryAttributeValue_whenString_shouldReturnStringAttribute() {
        // -- Arrange --
        let string = "test"

        // -- Act --
        let attribute = string.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.anyValue as? String, "test")
    }

    // MARK: - Bool Attributable Tests

    func testasSentryAttributeValue_whenBool_shouldReturnBooleanAttribute() {
        // -- Arrange --
        let bool = true

        // -- Act --
        let attribute = bool.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean")
        XCTAssertEqual(attribute.anyValue as? Bool, true)
    }

    // MARK: - Int Attributable Tests

    func testasSentryAttributeValue_whenInt_shouldReturnIntegerAttribute() {
        // -- Arrange --
        let int = 42

        // -- Act --
        let attribute = int.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.anyValue as? Int, 42)
    }

    // MARK: - Double Attributable Tests

    func testasSentryAttributeValue_whenDouble_shouldReturnDoubleAttribute() throws {
        // -- Arrange --
        let double = 3.14

        // -- Act --
        let attribute = double.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        let value = try XCTUnwrap(attribute.anyValue as? Double)
        XCTAssertEqual(value, 3.14, accuracy: 0.001)
    }

    // MARK: - Float Attributable Tests

    func testasSentryAttributeValue_whenFloat_shouldReturnDoubleAttribute() throws {
        // -- Arrange --
        let float: Float = 3.14

        // -- Act --
        let attribute = float.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        let value = try XCTUnwrap(attribute.anyValue as? Double)
        XCTAssertEqual(value, 3.14, accuracy: 0.001)
    }

    // MARK: - Array Attributable Tests

    func testasSentryAttributeValue_whenStringArray_shouldReturnStringArrayAttribute() {
        // -- Arrange --
        let array = ["a", "b", "c"]

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let value = attribute.anyValue as? [String]
        XCTAssertEqual(value, ["a", "b", "c"])
    }

    func testasSentryAttributeValue_whenBooleanArray_shouldReturnBooleanArrayAttribute() {
        // -- Arrange --
        let array = [true, false]

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let value = attribute.anyValue as? [Bool]
        XCTAssertEqual(value, [true, false])
    }

    func testasSentryAttributeValue_whenIntegerArray_shouldReturnIntegerArrayAttribute() {
        // -- Arrange --
        let array = [1, 2, 3]

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let value = attribute.anyValue as? [Int]
        XCTAssertEqual(value, [1, 2, 3])
    }

    func testasSentryAttributeValue_whenDoubleArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array = [1.1, 2.2, 3.3]

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.anyValue as? [Double]
        XCTAssertEqual(value, [1.1, 2.2, 3.3])
    }

    func testasSentryAttributeValue_whenFloatArray_shouldReturnDoubleArrayAttribute() throws {
        // -- Arrange --
        let array: [Float] = [1.1, 2.2, 3.3]

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = try XCTUnwrap(attribute.anyValue as? [Double])
        XCTAssertEqual(try XCTUnwrap(value.element(at: 0)), 1.1, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(value.element(at: 1)), 2.2, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(value.element(at: 2)), 3.3, accuracy: 0.01)
    }

    func testasSentryAttributeValue_whenEmptyStringArray_shouldReturnStringArrayAttribute() {
        // -- Arrange --
        let array: [String] = []

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let value = attribute.anyValue as? [String]
        XCTAssertEqual(value, [])
    }

    func testasSentryAttributeValue_whenEmptyBooleanArray_shouldReturnBooleanArrayAttribute() {
        // -- Arrange --
        let array: [Bool] = []

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let value = attribute.anyValue as? [Bool]
        XCTAssertEqual(value, [])
    }

    func testasSentryAttributeValue_whenEmptyIntegerArray_shouldReturnIntegerArrayAttribute() {
        // -- Arrange --
        let array: [Int] = []

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let value = attribute.anyValue as? [Int]
        XCTAssertEqual(value, [])
    }

    func testasSentryAttributeValue_whenEmptyDoubleArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array: [Double] = []

        // -- Act --
        let attribute = array.asSentryAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.anyValue as? [Double]
        XCTAssertEqual(value, [])
    }

    // MARK: - Encoding Tests

    func testEncode_whenStringAttribute_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let attribute = "test".asSentryAttributeValue
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "string")
        XCTAssertEqual(json?["value"] as? String, "test")
    }

    func testEncode_whenStringArrayAttribute_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let attribute = ["a", "b", "c"].asSentryAttributeValue
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "string[]")
        let array = json?["value"] as? [String]
        XCTAssertEqual(array, ["a", "b", "c"])
    }

    func testEncode_whenBooleanArrayAttribute_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let attribute = [true, false].asSentryAttributeValue
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "boolean[]")
        let array = json?["value"] as? [Bool]
        XCTAssertEqual(array, [true, false])
    }

    func testEncode_whenIntegerArrayAttribute_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let attribute = [1, 2, 3].asSentryAttributeValue
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "integer[]")
        let array = json?["value"] as? [Int]
        XCTAssertEqual(array, [1, 2, 3])
    }

    func testEncode_whenDoubleArrayAttribute_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let attribute = [1.1, 2.2, 3.3].asSentryAttributeValue
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(attribute)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "double[]")
        let array = json?["value"] as? [Double]
        XCTAssertEqual(array, [1.1, 2.2, 3.3])
    }
}
