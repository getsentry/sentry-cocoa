@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryAttributeValueTests: XCTestCase {

    // MARK: - Type Property Tests

    func testType_whenString_shouldReturnString() {
        // -- Arrange --
        let value = SentryAttributeValue.string("test")

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "string")
    }

    func testType_whenBoolean_shouldReturnBoolean() {
        // -- Arrange --
        let value = SentryAttributeValue.boolean(true)

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "boolean")
    }

    func testType_whenInteger_shouldReturnInteger() {
        // -- Arrange --
        let value = SentryAttributeValue.integer(42)

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "integer")
    }

    func testType_whenDouble_shouldReturnDouble() {
        // -- Arrange --
        let value = SentryAttributeValue.double(3.14)

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "double")
    }

    func testType_whenStringArray_shouldReturnStringArray() {
        // -- Arrange --
        let value = SentryAttributeValue.stringArray(["a", "b", "c"])

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "string[]")
    }

    func testType_whenBooleanArray_shouldReturnBooleanArray() {
        // -- Arrange --
        let value = SentryAttributeValue.booleanArray([true, false])

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "boolean[]")
    }

    func testType_whenIntegerArray_shouldReturnIntegerArray() {
        // -- Arrange --
        let value = SentryAttributeValue.integerArray([1, 2, 3])

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "integer[]")
    }

    func testType_whenDoubleArray_shouldReturnDoubleArray() {
        // -- Arrange --
        let value = SentryAttributeValue.doubleArray([1.1, 2.2, 3.3])

        // -- Act --
        let type = value.type

        // -- Assert --
        XCTAssertEqual(type, "double[]")
    }

    // MARK: - AnyValue Property Tests

    func testAnyValue_whenString_shouldReturnString() {
        // -- Arrange --
        let value = SentryAttributeValue.string("test")

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? String, "test")
    }

    func testAnyValue_whenBoolean_shouldReturnBoolean() {
        // -- Arrange --
        let value = SentryAttributeValue.boolean(true)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? Bool, true)
    }

    func testAnyValue_whenInteger_shouldReturnInteger() {
        // -- Arrange --
        let value = SentryAttributeValue.integer(42)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? Int, 42)
    }

    func testAnyValue_whenDouble_shouldReturnDouble() throws {
        // -- Arrange --
        let value = SentryAttributeValue.double(3.14)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(anyValue as? Double), 3.14, accuracy: 0.001)
    }

    func testAnyValue_whenStringArray_shouldReturnStringArray() {
        // -- Arrange --
        let array = ["a", "b", "c"]
        let value = SentryAttributeValue.stringArray(array)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? [String], array)
    }

    func testAnyValue_whenBooleanArray_shouldReturnBooleanArray() {
        // -- Arrange --
        let array = [true, false]
        let value = SentryAttributeValue.booleanArray(array)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? [Bool], array)
    }

    func testAnyValue_whenIntegerArray_shouldReturnIntegerArray() {
        // -- Arrange --
        let array = [1, 2, 3]
        let value = SentryAttributeValue.integerArray(array)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? [Int], array)
    }

    func testAnyValue_whenDoubleArray_shouldReturnDoubleArray() {
        // -- Arrange --
        let array = [1.1, 2.2, 3.3]
        let value = SentryAttributeValue.doubleArray(array)

        // -- Act --
        let anyValue = value.value

        // -- Assert --
        XCTAssertEqual(anyValue as? [Double], array)
    }

    // MARK: - Init FromAny Tests

    func testInitFromAny_whenString_shouldCreateString() {
        // -- Arrange --
        let input: Any = "test"

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .string(let stringValue) = value {
            XCTAssertEqual(stringValue, "test")
        } else {
            XCTFail("Expected string case")
        }
    }

    func testInitFromAny_whenBoolean_shouldCreateBoolean() {
        // -- Arrange --
        let input: Any = true

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .boolean(let boolValue) = value {
            XCTAssertEqual(boolValue, true)
        } else {
            XCTFail("Expected boolean case")
        }
    }

    func testInitFromAny_whenInteger_shouldCreateInteger() {
        // -- Arrange --
        let input: Any = 42

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .integer(let intValue) = value {
            XCTAssertEqual(intValue, 42)
        } else {
            XCTFail("Expected integer case")
        }
    }

    func testInitFromAny_whenDouble_shouldCreateDouble() {
        // -- Arrange --
        let input: Any = 3.14

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .double(let doubleValue) = value {
            XCTAssertEqual(doubleValue, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected double case")
        }
    }

    func testInitFromAny_whenFloat_shouldCreateDouble() {
        // -- Arrange --
        let input: Any = Float(3.14)

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .double(let doubleValue) = value {
            XCTAssertEqual(doubleValue, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected double case")
        }
    }

    func testInitFromAny_whenStringArray_shouldCreateStringArray() {
        // -- Arrange --
        let input: Any = ["a", "b", "c"]

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .stringArray(let arrayValue) = value {
            XCTAssertEqual(arrayValue, ["a", "b", "c"])
        } else {
            XCTFail("Expected stringArray case")
        }
    }

    func testInitFromAny_whenBooleanArray_shouldCreateBooleanArray() {
        // -- Arrange --
        let input: Any = [true, false]

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .booleanArray(let arrayValue) = value {
            XCTAssertEqual(arrayValue, [true, false])
        } else {
            XCTFail("Expected booleanArray case")
        }
    }

    func testInitFromAny_whenIntegerArray_shouldCreateIntegerArray() {
        // -- Arrange --
        let input: Any = [1, 2, 3]

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .integerArray(let arrayValue) = value {
            XCTAssertEqual(arrayValue, [1, 2, 3])
        } else {
            XCTFail("Expected integerArray case")
        }
    }

    func testInitFromAny_whenDoubleArray_shouldCreateDoubleArray() {
        // -- Arrange --
        let input: Any = [1.1, 2.2, 3.3]

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .doubleArray(let arrayValue) = value {
            XCTAssertEqual(arrayValue, [1.1, 2.2, 3.3])
        } else {
            XCTFail("Expected doubleArray case")
        }
    }

    func testInitFromAny_whenFloatArray_shouldCreateDoubleArray() {
        // -- Arrange --
        let input: Any = [Float(1.1), Float(2.2), Float(3.3)]

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .doubleArray(let arrayValue) = value {
            XCTAssertEqual(try XCTUnwrap(arrayValue.element(at: 0)), 1.1, accuracy: 0.01)
            XCTAssertEqual(try XCTUnwrap(arrayValue.element(at: 1)), 2.2, accuracy: 0.01)
            XCTAssertEqual(try XCTUnwrap(arrayValue.element(at: 2)), 3.3, accuracy: 0.01)
        } else {
            XCTFail("Expected doubleArray case")
        }
    }

    func testInitFromAny_whenHomogeneousSentryAttributeArray_shouldCreateTypedArray() {
        // -- Arrange --
        let attributes = [
            SentryAttribute(string: "a"),
            SentryAttribute(string: "b"),
            SentryAttribute(string: "c")
        ]
        let input: Any = attributes

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .stringArray(let arrayValue) = value {
            XCTAssertEqual(arrayValue, ["a", "b", "c"])
        } else {
            XCTFail("Expected stringArray case")
        }
    }

    func testInitFromAny_whenMixedSentryAttributeArray_shouldCreateStringArray() {
        // -- Arrange --
        let attributes = [
            SentryAttribute(string: "a"),
            SentryAttribute(integer: 1),
            SentryAttribute(boolean: true)
        ]
        let input: Any = attributes

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .stringArray(let arrayValue) = value {
            XCTAssertEqual(arrayValue.count, 3)
            XCTAssertTrue(arrayValue.contains("a"))
        } else {
            XCTFail("Expected stringArray case for mixed types")
        }
    }

    func testInitFromAny_whenEmptySentryAttributeArray_shouldCreateStringArray() {
        // -- Arrange --
        let attributes: [SentryAttribute] = []
        let input: Any = attributes

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .stringArray(let arrayValue) = value {
            XCTAssertTrue(arrayValue.isEmpty)
        } else {
            XCTFail("Expected stringArray case for empty array")
        }
    }

    func testInitFromAny_whenUnsupportedType_shouldCreateString() {
        // -- Arrange --
        let input: Any = Date()

        // -- Act --
        let value = SentryAttributeValue.from(anyValue: input)

        // -- Assert --
        if case .string(let stringValue) = value {
            XCTAssertFalse(stringValue.isEmpty)
        } else {
            XCTFail("Expected string case for unsupported type")
        }
    }

    // MARK: - Encoding Tests

    func testEncode_whenString_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeValue.string("test")
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "string")
        XCTAssertEqual(json?["value"] as? String, "test")
    }

    func testEncode_whenBoolean_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeValue.boolean(true)
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "boolean")
        XCTAssertEqual(json?["value"] as? Bool, true)
    }

    func testEncode_whenInteger_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeValue.integer(42)
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "integer")
        XCTAssertEqual(json?["value"] as? Int, 42)
    }

    func testEncode_whenDouble_shouldEncodeCorrectly() throws {
        // -- Arrange --
        let value = SentryAttributeValue.double(3.14)
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "double")
        XCTAssertEqual(try XCTUnwrap(json?["value"] as? Double), 3.14, accuracy: 0.001)
    }

    func testEncode_whenStringArray_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let value = SentryAttributeValue.stringArray(["a", "b", "c"])
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "string[]")
        let array = json?["value"] as? [String]
        XCTAssertEqual(array, ["a", "b", "c"])
    }

    func testEncode_whenBooleanArray_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let value = SentryAttributeValue.booleanArray([true, false])
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "boolean[]")
        let array = json?["value"] as? [Bool]
        XCTAssertEqual(array, [true, false])
    }

    func testEncode_whenIntegerArray_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let value = SentryAttributeValue.integerArray([1, 2, 3])
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "integer[]")
        let array = json?["value"] as? [Int]
        XCTAssertEqual(array, [1, 2, 3])
    }

    func testEncode_whenDoubleArray_shouldEncodeAsPrimitiveArray() throws {
        // -- Arrange --
        let value = SentryAttributeValue.doubleArray([1.1, 2.2, 3.3])
        let encoder = JSONEncoder()

        // -- Act --
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // -- Assert --
        XCTAssertEqual(json?["type"] as? String, "double[]")
        let array = json?["value"] as? [Double]
        XCTAssertEqual(array, [1.1, 2.2, 3.3])
    }

    // MARK: - ExpressibleByLiteral Tests

    func testExpressibleByStringLiteral_shouldCreateString() {
        // -- Arrange & Act --
        let value: SentryAttributeValue = "test"

        // -- Assert --
        if case .string(let stringValue) = value {
            XCTAssertEqual(stringValue, "test")
        } else {
            XCTFail("Expected string case")
        }
    }

    func testExpressibleByBooleanLiteral_shouldCreateBoolean() {
        // -- Arrange & Act --
        let value: SentryAttributeValue = true

        // -- Assert --
        if case .boolean(let boolValue) = value {
            XCTAssertEqual(boolValue, true)
        } else {
            XCTFail("Expected boolean case")
        }
    }

    func testExpressibleByIntegerLiteral_shouldCreateInteger() {
        // -- Arrange & Act --
        let value: SentryAttributeValue = 42

        // -- Assert --
        if case .integer(let intValue) = value {
            XCTAssertEqual(intValue, 42)
        } else {
            XCTFail("Expected integer case")
        }
    }

    func testExpressibleByFloatLiteral_shouldCreateDouble() {
        // -- Arrange & Act --
        let value: SentryAttributeValue = 3.14

        // -- Assert --
        if case .double(let doubleValue) = value {
            XCTAssertEqual(doubleValue, 3.14, accuracy: 0.001)
        } else {
            XCTFail("Expected double case")
        }
    }
}
