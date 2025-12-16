@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class AttributableTests: XCTestCase {

    // MARK: - String Attributable Tests

    func testAsAttribute_whenString_shouldReturnStringAttribute() {
        // -- Arrange --
        let string = "test"

        // -- Act --
        let attribute = string.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "string")
        XCTAssertEqual(attribute.value as? String, "test")
    }

    // MARK: - Bool Attributable Tests

    func testAsAttribute_whenBool_shouldReturnBooleanAttribute() {
        // -- Arrange --
        let bool = true

        // -- Act --
        let attribute = bool.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean")
        XCTAssertEqual(attribute.value as? Bool, true)
    }

    // MARK: - Int Attributable Tests

    func testAsAttribute_whenInt_shouldReturnIntegerAttribute() {
        // -- Arrange --
        let int = 42

        // -- Act --
        let attribute = int.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer")
        XCTAssertEqual(attribute.value as? Int, 42)
    }

    // MARK: - Double Attributable Tests

    func testAsAttribute_whenDouble_shouldReturnDoubleAttribute() {
        // -- Arrange --
        let double = 3.14

        // -- Act --
        let attribute = double.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14, accuracy: 0.001)
    }

    // MARK: - Float Attributable Tests

    func testAsAttribute_whenFloat_shouldReturnDoubleAttribute() {
        // -- Arrange --
        let float: Float = 3.14

        // -- Act --
        let attribute = float.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "double")
        XCTAssertEqual(attribute.value as? Double, 3.14, accuracy: 0.001)
    }

    // MARK: - Array Attributable Tests

    func testAsAttribute_whenStringArray_shouldReturnStringArrayAttribute() {
        // -- Arrange --
        let array = ["a", "b", "c"]

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let value = attribute.value as? [String]
        XCTAssertEqual(value, ["a", "b", "c"])
    }

    func testAsAttribute_whenBooleanArray_shouldReturnBooleanArrayAttribute() {
        // -- Arrange --
        let array = [true, false]

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let value = attribute.value as? [Bool]
        XCTAssertEqual(value, [true, false])
    }

    func testAsAttribute_whenIntegerArray_shouldReturnIntegerArrayAttribute() {
        // -- Arrange --
        let array = [1, 2, 3]

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let value = attribute.value as? [Int]
        XCTAssertEqual(value, [1, 2, 3])
    }

    func testAsAttribute_whenDoubleArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array = [1.1, 2.2, 3.3]

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.value as? [Double]
        XCTAssertEqual(value, [1.1, 2.2, 3.3])
    }

    func testAsAttribute_whenFloatArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array: [Float] = [1.1, 2.2, 3.3]

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.value as? [Double]
        XCTAssertEqual(value, [1.1, 2.2, 3.3], accuracy: 0.01)
    }

    func testAsAttribute_whenEmptyStringArray_shouldReturnStringArrayAttribute() {
        // -- Arrange --
        let array: [String] = []

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "string[]")
        let value = attribute.value as? [String]
        XCTAssertEqual(value, [])
    }

    func testAsAttribute_whenEmptyBooleanArray_shouldReturnBooleanArrayAttribute() {
        // -- Arrange --
        let array: [Bool] = []

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "boolean[]")
        let value = attribute.value as? [Bool]
        XCTAssertEqual(value, [])
    }

    func testAsAttribute_whenEmptyIntegerArray_shouldReturnIntegerArrayAttribute() {
        // -- Arrange --
        let array: [Int] = []

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "integer[]")
        let value = attribute.value as? [Int]
        XCTAssertEqual(value, [])
    }

    func testAsAttribute_whenEmptyDoubleArray_shouldReturnDoubleArrayAttribute() {
        // -- Arrange --
        let array: [Double] = []

        // -- Act --
        let attribute = array.asAttribute

        // -- Assert --
        XCTAssertEqual(attribute.type, "double[]")
        let value = attribute.value as? [Double]
        XCTAssertEqual(value, [])
    }

    // MARK: - SentryAttribute Attributable Tests

    func testAsAttribute_whenSentryAttribute_shouldReturnSelf() {
        // -- Arrange --
        let attribute = SentryAttribute(string: "test")

        // -- Act --
        let result = attribute.asAttribute

        // -- Assert --
        XCTAssertTrue(result === attribute, "asAttribute should return self for SentryAttribute")
    }

    // MARK: - Encoding Tests

    func testEncode_whenStringAttribute_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let attribute = "test".asAttribute
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
        let attribute = ["a", "b", "c"].asAttribute
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
        let attribute = [true, false].asAttribute
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
        let attribute = [1, 2, 3].asAttribute
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
        let attribute = [1.1, 2.2, 3.3].asAttribute
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
