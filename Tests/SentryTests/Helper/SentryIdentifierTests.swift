#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryIdentifierTests: XCTestCase {

    private enum Owner {}
    private typealias ID = SentryIdentifier<Owner, String>

    func testEquality_whenRawValuesAreEqual_shouldBeEqual() {
        // -- Arrange --
        let first = ID(rawValue: "id")
        let second = ID(rawValue: "id")

        // -- Act & Assert --
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.hashValue, second.hashValue)
    }

    func testEquality_whenRawValuesDiffer_shouldNotBeEqual() {
        // -- Arrange --
        let first = ID(rawValue: "id")
        let second = ID(rawValue: "other-id")

        // -- Act & Assert --
        XCTAssertNotEqual(first, second)
    }

    func testRawValue_shouldRoundTrip() {
        // -- Act --
        let id = ID(rawValue: "id")

        // -- Assert --
        XCTAssertEqual(id.rawValue, "id")
    }

    func testDescription_shouldBeTheRawValue() {
        // -- Arrange --
        let id = ID(rawValue: "id")

        // -- Act & Assert --
        XCTAssertEqual("\(id)", "id")
    }

    func testDescription_whenRawValueIsNotAString_shouldDescribeTheRawValue() {
        // -- Arrange --
        let id = SentryIdentifier<Owner, Int>(rawValue: 7)

        // -- Act & Assert --
        XCTAssertEqual("\(id)", "7")
    }
}
