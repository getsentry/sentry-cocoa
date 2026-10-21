#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@testable import Sentry
#endif
import XCTest

final class SequenceExtensionsTests: XCTestCase {
    func testUnique_whenEmpty_shouldReturnEmpty() {
        // -- Arrange --
        let input: [Int] = []

        // -- Act --
        let result = input.unique(by: { $0 })

        // -- Assert --
        XCTAssertEqual(result, [])
    }

    func testUnique_whenSingleElement_shouldReturnElement() {
        // -- Arrange --
        let input = [42]

        // -- Act --
        let result = input.unique(by: { $0 })

        // -- Assert --
        XCTAssertEqual(result, [42])
    }

    func testUnique_whenAllKeysDistinct_shouldPreserveOrder() {
        // -- Arrange --
        let input = [3, 1, 2]

        // -- Act --
        let result = input.unique(by: { $0 })

        // -- Assert --
        XCTAssertEqual(result, [3, 1, 2])
    }

    func testUnique_whenAllKeysEqual_shouldReturnFirstElement() {
        // -- Arrange --
        let input = ["first", "second", "third"]

        // -- Act --
        let result = input.unique(by: { _ in 0 })

        // -- Assert --
        XCTAssertEqual(result, ["first"])
    }

    func testUnique_whenDuplicateKeys_shouldPreserveFirstOccurrenceOrder() {
        // -- Arrange --
        let input = [3, 1, 3, 2, 1, 2]

        // -- Act --
        let result = input.unique(by: { $0 })

        // -- Assert --
        XCTAssertEqual(result, [3, 1, 2])
    }

    func testUnique_whenElementsNotHashable_shouldDeduplicateByKey() {
        // -- Arrange --
        struct Item: Equatable {
            let id: Int
            let name: String
        }
        let first = Item(id: 2, name: "first")
        let second = Item(id: 1, name: "second")
        let input = [first, second, Item(id: 2, name: "duplicate")]

        // -- Act --
        let result = input.unique(by: { $0.id })

        // -- Assert --
        XCTAssertEqual(result, [first, second])
    }

    func testUnique_whenSequenceNotCollection_shouldReturnUniqueElements() {
        // -- Arrange --
        let input = AnySequence([2, 1, 2, 3, 1])

        // -- Act --
        let result = input.unique(by: { $0 })

        // -- Assert --
        XCTAssertEqual(result, [2, 1, 3])
    }
}
