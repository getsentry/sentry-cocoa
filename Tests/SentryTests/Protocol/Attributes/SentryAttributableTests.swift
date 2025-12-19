@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryAttributableTests: XCTestCase {

    // MARK: - String Attributable Tests

    func testasAttributeValue_whenString_shouldReturnStringAttribute() {
        // -- Arrange --
        let string = "test"

        // -- Act --
        let attribute = string.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "test")
    }

    // MARK: - Bool Attributable Tests

    func testasAttributeValue_whenBool_shouldReturnBooleanAttribute() {
        // -- Arrange --
        let bool = true

        // -- Act --
        let attribute = bool.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean")
        XCTAssertEqual(attribute.value as? Bool, true)
    }

    // MARK: - Int Attributable Tests

    func testasAttributeValue_whenInt_shouldReturnIntegerAttribute() {
        // -- Arrange --
        let int = 42

        // -- Act --
        let attribute = int.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }

    // MARK: - Double Attributable Tests

    func testasAttributeValue_whenDouble_shouldReturnDoubleAttribute() throws {
        // -- Arrange --
        let double = 3.14

        // -- Act --
        let attribute = double.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        let value = try XCTUnwrap(attribute.value as? Double)
        XCTAssertEqual(value, 3.14, accuracy: 0.001)
    }

    // MARK: - Float Attributable Tests

    func testasAttributeValue_whenFloat_shouldReturnDoubleAttribute() throws {
        // -- Arrange --
        let float: Float = 3.14

        // -- Act --
        let attribute = float.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        let value = try XCTUnwrap(attribute.value as? Double)
        XCTAssertEqual(value, 3.14, accuracy: 0.001)
    }

    // MARK: - Array Attributable Tests

    func testasAttributeValue_whenStringArray_shouldReturnStringArrayAttribute() {
        // -- Arrange --
        let array = ["a", "b", "c"]

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let value = attribute.value as? [String]
        XCTAssertEqual(value, ["a", "b", "c"])
    }

    func testasAttributeValue_whenBooleanArray_shouldReturnBooleanArrayAttribute() {
        // -- Arrange --
        let array = [true, false]

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let value = attribute.value as? [Bool]
        XCTAssertEqual(value, [true, false])
    }

    func testasAttributeValue_whenIntegerArray_shouldReturnIntegerArrayAttribute() {
        // -- Arrange --
        let array = [1, 2, 3]

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let value = attribute.value as? [Int]
        XCTAssertEqual(value, [1, 2, 3])
    }

    func testasAttributeValue_whenDoubleArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array = [1.1, 2.2, 3.3]

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.value as? [Double]
        XCTAssertEqual(value, [1.1, 2.2, 3.3])
    }

    func testasAttributeValue_whenFloatArray_shouldReturnDoubleArrayAttribute() throws {
        // -- Arrange --
        let array: [Float] = [1.1, 2.2, 3.3]

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = try XCTUnwrap(attribute.value as? [Double])
        XCTAssertEqual(try XCTUnwrap(value.element(at: 0)), 1.1, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(value.element(at: 1)), 2.2, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(value.element(at: 2)), 3.3, accuracy: 0.01)
    }

    func testasAttributeValue_whenEmptyStringArray_shouldReturnStringArrayAttribute() {
        // -- Arrange --
        let array: [String] = []

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let value = attribute.value as? [String]
        XCTAssertEqual(value, [])
    }

    func testasAttributeValue_whenEmptyBooleanArray_shouldReturnBooleanArrayAttribute() {
        // -- Arrange --
        let array: [Bool] = []

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let value = attribute.value as? [Bool]
        XCTAssertEqual(value, [])
    }

    func testasAttributeValue_whenEmptyIntegerArray_shouldReturnIntegerArrayAttribute() {
        // -- Arrange --
        let array: [Int] = []

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let value = attribute.value as? [Int]
        XCTAssertEqual(value, [])
    }

    func testasAttributeValue_whenEmptyDoubleArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array: [Double] = []

        // -- Act --
        let attribute = array.asAttributeValue

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.value as? [Double]
        XCTAssertEqual(value, [])
    }

    // MARK: - SentryAttribute Attributable Tests

    func testasAttributeValue_whenSentryAttribute_shouldReturnSelf() {
        // -- Arrange --
        let attribute = SentryAttribute(string: "test")

        // -- Act --
        let result = attribute.asAttributeValue

        // -- Assert --
        XCTAssertTrue(result === attribute, "asAttributeValue should return self for SentryAttribute")
    }

    // MARK: - Encoding Tests

    func testEncode_whenStringAttribute_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let attribute = "test".asAttributeValue
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
        let attribute = ["a", "b", "c"].asAttributeValue
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
        let attribute = [true, false].asAttributeValue
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
        let attribute = [1, 2, 3].asAttributeValue
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
        let attribute = [1.1, 2.2, 3.3].asAttributeValue
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
