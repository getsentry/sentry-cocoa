#if SWIFT_PACKAGE
@testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest

final class TypedIndexTests: XCTestCase {
    private enum Node {}

    func testEncode_whenIndexIsProvided_shouldEncodeScalarInteger() throws {
        // -- Arrange --
        let index = TypedIndex<Node, Int>(42)

        // -- Act --
        let data = try JSONEncoder().encode(index)

        // -- Assert --
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "42")
    }

    func testHashable_whenValuesMatch_shouldResolveSameDictionaryEntry() {
        // -- Arrange --
        let indices: [TypedIndex<Node, Int>: String] = [.init(1): "first", .init(2): "second"]

        // -- Act --
        let first = indices[TypedIndex<Node, Int>(1)]
        let second = indices[TypedIndex<Node, Int>(2)]
        let missing = indices[TypedIndex<Node, Int>(3)]

        // -- Assert --
        XCTAssertEqual(first, "first")
        XCTAssertEqual(second, "second")
        XCTAssertNil(missing)
    }

    func testDecode_whenValueHasWrongType_shouldThrow() {
        // -- Arrange --
        let data = Data(#""42""#.utf8)

        // -- Act & Assert --
        XCTAssertThrowsError(try JSONDecoder().decode(TypedIndex<Node, Int>.self, from: data))
    }

    func testCodable_whenValuesAreIntegerLimits_shouldPreserveExactValues() throws {
        for value in [Int.min, 0, Int.max] {
            // -- Arrange --
            let index = TypedIndex<Node, Int>(value)

            // -- Act --
            let data = try JSONEncoder().encode(index)
            let decoded = try JSONDecoder().decode(TypedIndex<Node, Int>.self, from: data)

            // -- Assert --
            XCTAssertEqual(String(decoding: data, as: UTF8.self), String(value))
            XCTAssertEqual(decoded.value, value)
        }
    }

    func testDecode_whenScalarIntegerIsProvided_shouldRetainValue() throws {
        // -- Arrange --
        let data = Data("42".utf8)

        // -- Act --
        let index = try JSONDecoder().decode(TypedIndex<Node, Int>.self, from: data)

        // -- Assert --
        XCTAssertEqual(index.value, 42)
    }
}
