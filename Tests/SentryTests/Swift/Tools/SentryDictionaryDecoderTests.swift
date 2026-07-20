@testable import Sentry
import XCTest

final class SentryDictionaryDecoderTests: XCTestCase {

    // MARK: - Bool

    func testBool_whenKeyIsMissing_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let result = SentryDictionaryDecoder.bool(dictionary, "missing")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testBool_whenValueIsNSNull_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNull()]

        // -- Act --
        let result = SentryDictionaryDecoder.bool(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testBool_whenValueIsNSNumberTrue_shouldReturnTrue() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNumber(value: true)]

        // -- Act --
        let result = SentryDictionaryDecoder.bool(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result, true)
    }

    func testBool_whenValueIsNSNumberFalse_shouldReturnFalse() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNumber(value: false)]

        // -- Act --
        let result = SentryDictionaryDecoder.bool(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result, false)
    }

    func testBool_whenValueIsNotNSNumber_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": "true"]

        // -- Act --
        let result = SentryDictionaryDecoder.bool(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - Is Bool

    func testIsBool_whenObjCTypeIsChar_shouldReturnTrue() {
        // -- Arrange --
        let number = NSNumber(value: true)

        // -- Act --
        let result = SentryDictionaryDecoder.isBool(number)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsBool_whenObjCTypeIsNotBool_shouldReturnFalse() {
        // -- Arrange --
        let number = NSNumber(value: 1)

        // -- Act --
        let result = SentryDictionaryDecoder.isBool(number)

        // -- Assert --
        XCTAssertFalse(result)
    }

    // MARK: - UInt

    func testUInt_whenKeyIsMissing_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let result = SentryDictionaryDecoder.uint(dictionary, "missing")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testUInt_whenValueIsNSNull_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNull()]

        // -- Act --
        let result = SentryDictionaryDecoder.uint(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testUInt_whenValueIsNotNSNumber_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": "1"]

        // -- Act --
        let result = SentryDictionaryDecoder.uint(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testUInt_whenValueIsNegative_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNumber(value: -1)]

        // -- Act --
        let result = SentryDictionaryDecoder.uint(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testUInt_whenValueIsZero_shouldReturnZero() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNumber(value: 0)]

        // -- Act --
        let result = SentryDictionaryDecoder.uint(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result, 0)
    }

    func testUInt_whenValueIsPositive_shouldReturnUInt() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNumber(value: 42)]

        // -- Act --
        let result = SentryDictionaryDecoder.uint(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result, 42)
    }

    // MARK: - Dictionary

    func testDictionary_whenKeyIsMissing_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let result = SentryDictionaryDecoder.dictionary(dictionary, "missing")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testDictionary_whenValueIsNSNull_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNull()]

        // -- Act --
        let result = SentryDictionaryDecoder.dictionary(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testDictionary_whenValueIsDictionary_shouldReturnDictionary() {
        // -- Arrange --
        let expected: [String: Any] = ["nested": "value"]
        let dictionary: [String: Any] = ["value": expected]

        // -- Act --
        let result = SentryDictionaryDecoder.dictionary(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result as? [String: String], expected as? [String: String])
    }

    func testDictionary_whenValueIsNotDictionary_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": ["nested"]]

        // -- Act --
        let result = SentryDictionaryDecoder.dictionary(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - Strings

    func testStrings_whenKeyIsMissing_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let result = SentryDictionaryDecoder.strings(dictionary, "missing")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testStrings_whenValueIsNSNull_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": NSNull()]

        // -- Act --
        let result = SentryDictionaryDecoder.strings(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testStrings_whenValueIsNotArray_shouldReturnNil() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": "one"]

        // -- Act --
        let result = SentryDictionaryDecoder.strings(dictionary, "value")

        // -- Assert --
        XCTAssertNil(result)
    }

    func testStrings_whenValueIsStringArray_shouldReturnStrings() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": ["one", "two"]]

        // -- Act --
        let result = SentryDictionaryDecoder.strings(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result, ["one", "two"])
    }

    func testStrings_whenArrayContainsNonStrings_shouldReturnOnlyStrings() {
        // -- Arrange --
        let dictionary: [String: Any] = ["value": ["one", 2, NSNull(), "three"]]

        // -- Act --
        let result = SentryDictionaryDecoder.strings(dictionary, "value")

        // -- Assert --
        XCTAssertEqual(result, ["one", "three"])
    }
}

@objc(SentryDictionaryDecoderObjCHelper)
final class SentryDictionaryDecoderObjCHelper: NSObject {
    @objc(boolWithDictionary:key:)
    static func bool(_ dictionary: NSDictionary, key: String) -> NSNumber? {
        guard let result = SentryDictionaryDecoder.bool(swiftDictionary(dictionary), key) else {
            return nil
        }
        return NSNumber(value: result)
    }

    @objc static func isBool(_ number: NSNumber) -> Bool {
        SentryDictionaryDecoder.isBool(number)
    }

    @objc(uintWithDictionary:key:)
    static func uint(_ dictionary: NSDictionary, key: String) -> NSNumber? {
        guard let result = SentryDictionaryDecoder.uint(swiftDictionary(dictionary), key) else {
            return nil
        }
        return NSNumber(value: result)
    }

    @objc(dictionaryWithDictionary:key:)
    static func dictionary(_ dictionary: NSDictionary, key: String) -> NSDictionary? {
        guard let result = SentryDictionaryDecoder.dictionary(swiftDictionary(dictionary), key) else {
            return nil
        }
        return result as NSDictionary
    }

    @objc(stringsWithDictionary:key:)
    static func strings(_ dictionary: NSDictionary, key: String) -> NSArray? {
        guard let result = SentryDictionaryDecoder.strings(swiftDictionary(dictionary), key) else {
            return nil
        }
        return result as NSArray
    }

    private static func swiftDictionary(_ dictionary: NSDictionary) -> [String: Any] {
        dictionary as? [String: Any] ?? [:]
    }
}
