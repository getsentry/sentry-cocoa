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

    func testEncode_shouldEncodeTheRawValueAlone() throws {
        // -- Arrange --
        let holder = Holder(id: ID(rawValue: "id"), number: SentryIdentifier<Owner, Int>(rawValue: 7))

        // -- Act --
        let data = try JSONEncoder().encode(holder)

        // -- Assert --
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["id"] as? String, "id")
        XCTAssertEqual(json["number"] as? Int, 7)
    }

    func testDecode_whenValueIsTheRawValue_shouldReturnTheID() throws {
        // -- Arrange --
        let data = Data(#"{"id":"id","number":7}"#.utf8)

        // -- Act --
        let holder = try JSONDecoder().decode(Holder.self, from: data)

        // -- Assert --
        XCTAssertEqual(holder.id, ID(rawValue: "id"))
        XCTAssertEqual(holder.number, SentryIdentifier<Owner, Int>(rawValue: 7))
    }

    func testDecode_whenValueHasAnotherType_shouldThrow() {
        // -- Arrange --
        let data = Data(#"{"id":7,"number":7}"#.utf8)

        // -- Act & Assert --
        XCTAssertThrowsError(try JSONDecoder().decode(Holder.self, from: data))
    }

    /// A type whose `Codable` conformance is synthesized from its IDs.
    private struct Holder: Codable {
        let id: ID
        let number: SentryIdentifier<Owner, Int>
    }
}
