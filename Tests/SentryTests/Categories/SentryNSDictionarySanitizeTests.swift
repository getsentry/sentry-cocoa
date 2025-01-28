@testable import Sentry
import SentryTestUtils
import XCTest

class SentryNSDictionarySanitizeTests: XCTestCase {
    func testSentrySanitize_dictionaryIsNil_shouldReturnNil() {
        // Arrange
        let dict: [String: Any]? = nil
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertNil(sanitized)
    }

    func testSentrySanitize_dictionaryIsNSNull_shouldReturnNil() {
        // Act
        let sanitized = sentry_sanitize_with_nsnull()
        // Assert
        XCTAssertNil(sanitized)
    }

    func testSentrySanitize_dictionaryIsEmpty_shouldReturnEmptyDictionary() {
        // Arrange
        let dict = [String: Any]()
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?.count, 0)
    }

    func testSentrySanitize_dictionaryKeyIsString_shouldUseKey() {
        // Arrange
        let dict = ["key": "value"]
        // Act
        let sanitized = sentry_sanitize(dict)
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
        let sanitized = sentry_sanitize(dict)
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
        let sanitized = sentry_sanitize(dict)
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
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?.count, 1)
        XCTAssertEqual(sanitized?["key"] as? String, "value 3")
    }

    func testSentrySanitize_dictionaryValueIsString_shouldUseValue() {
        // Arrange
        let dict = ["key": "value"]
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? String, "value")
    }

    func testSentrySanitize_dictionaryValueIsNumber_shouldUseValueDescription() {
        // Arrange
        let dict = ["key": 123]
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? Int, 123)
    }

    func testSentrySanitize_dictionaryValueIsDictionary_shouldSanitizeValue() {
        // Arrange
        let dict = ["key": ["__sentry": "value 1", "key": "value 2"]]
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? [String: String], ["key": "value 2"])
    }

    func testSentrySanitize_dictionaryValueIsArray_shouldSanitizeEveryElement() {
        // Arrange
        let dict = ["key": ["value", "value 2"]]
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? [String], ["value", "value 2"])
    }

    func testSentrySanitize_dictionaryValueIsDate_shouldUseISO8601FormatAsValue() {
        // Arrange
        let date = Date(timeIntervalSince1970: 1_234)
        let dict = ["key": date]
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        XCTAssertEqual(sanitized?["key"] as? String, "1970-01-01T00:20:34.000Z")
    }

    func testSentrySanitize_dictionaryValueIsOtherType_shouldUseObjectDescriptionAsValue() throws {
        // Arrange
        let dict = ["key": NSObject()]
        // Act
        let sanitized = sentry_sanitize(dict)
        // Assert
        let value = try XCTUnwrap(sanitized?["key"] as? String)
        let regex = try NSRegularExpression(pattern: "^<NSObject: 0x[0-9a-f]+>$")
        let result = regex.matches(in: value, range: NSRange(location: 0, length: value.count))
        XCTAssertFalse(result.isEmpty)
    }
}
