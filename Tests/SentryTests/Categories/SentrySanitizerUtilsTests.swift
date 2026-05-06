@testable import Sentry
import SentryTestUtils
import XCTest

class SentryNSDictionarySanitizeTests: XCTestCase {
    func testSentrySanitize_dictionaryIsNil_shouldReturnNil() {
        // Arrange
        let dict: [String: Any]? = nil
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertNil(sanitized)
    }

    func testSentrySanitize_dictionaryIsNSNull_shouldReturnNil() {
        // Act
        let sanitized = sentry_sanitize_with_nsnull()
        // Assert
        XCTAssertNil(sanitized)
    }

    func testSentrySanitize_parameterIsNotNSDictionary_shouldReturnNil() {
        // Act
        let sanitized = sentry_sanitize_with_non_dictionary()
        // Assert
        XCTAssertNil(sanitized)
    }

    func testSentrySanitize_dictionaryIsEmpty_shouldReturnEmptyDictionary() {
        // Arrange
        let dict = [String: Any]()
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?.count, 0)
    }

    func testSentrySanitize_dictionaryKeyIsString_shouldUseKey() {
        // Arrange
        let dict = ["key": "value"]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? String, "value")
    }

    func testSentrySanitize_dictionaryKeyIsNotString_shouldUseKeyDescriptionAsKey() {
        // Arrange
        let dict: [AnyHashable: Any] = [
            1: "number value",
            Float(0.123456789): "float value",
            Double(9.87654321): "double value",
            Date(timeIntervalSince1970: 1_234): "date value"
        ]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?.count, 4)
        XCTAssertEqual(sanitized?["1"] as? String, "number value")
        XCTAssertEqual(sanitized?["0.1234568"] as? String, "float value")
        XCTAssertEqual(sanitized?["9.876543209999999"] as? String, "double value")
        XCTAssertEqual(sanitized?["1970-01-01 00:20:34 +0000"] as? String, "date value")
    }

    func testSentrySanitize_dictionaryKeyIsBoolean_willCollideWithNumberKey() {
        // This test is only added for locking down the expected behaviour.
        // The key `true` is bridged to a `_NSCFBoolean` which is a type alias
        // for `CFBoolean` which is defined as `1` for `true` and `0` for `false`.
        // Therefore any boolean will be casted to a number and treated equally.

        // Arrange
        let dict: [AnyHashable: Any] = [
            1: "number value",
            true: "bool value"
        ]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?.count, 1)
        // The order is not deterministic, so it can be either one.
        let value = sanitized?["1"] as? String
        XCTAssertTrue(value == "number value" || value == "bool value")
    }

    func testSentrySanitize_keyStartsWithSentryIdentifier_shouldIgnoreValue() {
        // Arrange
        let dict = ["__sentry_key": "value", "__sentry": "value 2", "key": "value 3"]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?.count, 1)
        XCTAssertEqual(sanitized?["key"] as? String, "value 3")
    }

    func testSentrySanitize_dictionaryValueIsString_shouldUseValue() {
        // Arrange
        let dict = ["key": "value"]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? String, "value")
    }

    func testSentrySanitize_dictionaryValueIsNumber_shouldUseValue() {
        // Arrange
        let dict = ["key": 123]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? Int, 123)
    }

    func testSentrySanitize_dictionaryValueIsDictionary_shouldSanitizeValue() {
        // Arrange
        let dict = ["key": ["__sentry": "value 1", "key": "value 2"]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? [String: String], ["key": "value 2"])
    }

    func testSentrySanitize_dictionaryValueIsArray_shouldSanitizeEveryElement() {
        // Arrange
        let dict = ["key": ["value", "value 2"]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? [String], ["value", "value 2"])
    }

    func testSentrySanitize_dictionaryValueIsDate_shouldUseISO8601FormatAsValue() {
        // Arrange
        let date = Date(timeIntervalSince1970: 1_234)
        let dict = ["key": date]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? String, "1970-01-01T00:20:34.000Z")
    }

    func testSentrySanitize_dictionaryValueIsOtherType_shouldUseObjectDescriptionAsValue() throws {
        // Arrange
        let dict = ["key": NSObject()]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let value = try XCTUnwrap(sanitized?["key"] as? String)
        let regex = try NSRegularExpression(pattern: "^<NSObject: 0x[0-9a-f]+>$")
        let result = regex.matches(in: value, range: NSRange(location: 0, length: value.count))
        XCTAssertFalse(result.isEmpty)
    }

    func testSentrySanitize_deeplyNestedDictionary_shouldTruncateAtMaxDepth() {
        // Arrange
        var dict: [String: Any] = ["leaf": "value"]
        for _ in 0..<250 {
            dict = ["nested": dict]
        }

        // Act
        let sanitized = sentry_sanitize_dictionary(dict)

        // Assert
        XCTAssertNotNil(sanitized)
        var current: [String: Any]? = sanitized as? [String: Any]
        var depth = 0
        while let next = current?["nested"] as? [String: Any] {
            current = next
            depth += 1
        }
        XCTAssertEqual(depth, 199)
    }

    // MARK: - Array value sanitization

    func testSentrySanitize_arrayValueWithStrings_shouldReturnSameStrings() throws {
        // Arrange
        let dict: [String: Any] = ["key": ["hello", "world", "test"]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [String])
        XCTAssertEqual(array, ["hello", "world", "test"])
    }

    func testSentrySanitize_arrayValueWithNumbers_shouldReturnSameNumbers() throws {
        // Arrange
        let dict: [String: Any] = ["key": [NSNumber(value: 42), NSNumber(value: 3.14), NSNumber(value: true)]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [Any])
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0] as? NSNumber, NSNumber(value: 42))
        XCTAssertEqual(array[1] as? NSNumber, NSNumber(value: 3.14))
        XCTAssertEqual(array[2] as? NSNumber, NSNumber(value: true))
    }

    func testSentrySanitize_arrayValueWithNestedDictionaries_shouldSanitize() throws {
        // Arrange
        let dict: [String: Any] = ["key": [["key1": "value1", "__sentry": "hidden"], ["key2": "value2"]]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [[String: Any]])
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0]["key1"] as? String, "value1")
        XCTAssertNil(array[0]["__sentry"])
        XCTAssertEqual(array[1]["key2"] as? String, "value2")
    }

    func testSentrySanitize_arrayValueWithNestedArrays_shouldRecursivelySanitize() throws {
        // Arrange
        let dict: [String: Any] = ["key": [["nested1", NSNumber(value: 456)], "topLevel"]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [Any])
        XCTAssertEqual(array.count, 2)
        let nested = try XCTUnwrap(array[0] as? [Any])
        XCTAssertEqual(nested[0] as? String, "nested1")
        XCTAssertEqual(nested[1] as? NSNumber, NSNumber(value: 456))
        XCTAssertEqual(array[1] as? String, "topLevel")
    }

    func testSentrySanitize_arrayValueWithDates_shouldConvertToISO8601String() throws {
        // Arrange
        let date = Date(timeIntervalSince1970: 1_640_995_200)
        let dict: [String: Any] = ["key": [date]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [Any])
        XCTAssertEqual(array[0] as? String, "2022-01-01T00:00:00.000Z")
    }

    func testSentrySanitize_arrayValueWithOtherObjects_shouldUseDescription() throws {
        // Arrange
        let dict: [String: Any] = ["key": [NSObject()]]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [Any])
        let description = try XCTUnwrap(array[0] as? String)
        let regex = try NSRegularExpression(pattern: "^<NSObject: 0x[0-9a-f]+>$")
        let result = regex.matches(in: description, range: NSRange(location: 0, length: description.count))
        XCTAssertFalse(result.isEmpty)
    }

    func testSentrySanitize_arrayValueWithMixedTypes_shouldHandleAllTypes() throws {
        // Arrange
        let date = Date(timeIntervalSince1970: 1_640_995_200)
        let innerArray: [Any] = ["string", NSNumber(value: 42), ["nested": "value"], ["inner"], date]
        let dict: [String: Any] = ["key": innerArray]
        // Act
        let sanitized = sentry_sanitize_dictionary(dict)
        // Assert
        let array = try XCTUnwrap(sanitized?["key"] as? [Any])
        XCTAssertEqual(array.count, 5)
        XCTAssertEqual(array[0] as? String, "string")
        XCTAssertEqual(array[1] as? NSNumber, NSNumber(value: 42))
        XCTAssertNotNil(array[2] as? [String: Any])
        XCTAssertNotNil(array[3] as? [Any])
        XCTAssertEqual(array[4] as? String, "2022-01-01T00:00:00.000Z")
    }

    func testSentrySanitize_deeplyNestedArrayInDictionary_shouldTruncateAtMaxDepth() {
        // Arrange
        var inner: [Any] = ["leaf"]
        for _ in 0..<250 {
            inner = [inner]
        }
        let dict: [String: Any] = ["key": inner]

        // Act
        let sanitized = sentry_sanitize_dictionary(dict)

        // Assert
        XCTAssertNotNil(sanitized)
        var current = sanitized?["key"] as? [Any]
        var depth = 0
        while let next = current?.first as? [Any] {
            current = next
            depth += 1
        }
        XCTAssertEqual(depth, 199)
    }
}
