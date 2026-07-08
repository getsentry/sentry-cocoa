@_spi(Private) @testable import Sentry
import XCTest

class SentryKeyValueCollectionBehaviorTests: XCTestCase {

    // MARK: - Defaults

    func testOff() {
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .off
        XCTAssertEqual(behavior, .off)
    }

    func testDenyList_withoutTerms_shouldHaveEmptyTerms() {
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .denyList()
        XCTAssertEqual(behavior, .denyList(terms: []))
    }

    func testDenyList_withTerms_shouldStoreTerms() {
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["x-custom", "secret"])
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom", "secret"]))
    }

    func testAllowList_shouldStoreTerms() {
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .allowList(terms: ["content-type"])
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenModeIsOff_shouldReturnOff() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "off"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .off)
    }

    func testInitWithDictionary_whenModeIsDenyListWithTerms_shouldReturnDenyListWithTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "denyList", "terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom"]))
    }

    func testInitWithDictionary_whenModeIsAllowListWithTerms_shouldReturnAllowListWithTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": ["content-type"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
    }

    func testInitWithDictionary_whenModeIsMissing_shouldDefaultToDenyList() {
        // -- Arrange --
        let dictionary: [String: Any] = ["terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom"]))
    }

    func testInitWithDictionary_whenModeIsUnknown_shouldDefaultToDenyList() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "unknown", "terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
    }

    func testInitWithDictionary_whenModeIsNSNull_shouldDefaultToDenyList() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": NSNull()]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
    }

    func testInitWithDictionary_whenTermsContainsNonStrings_shouldIgnoreNonStrings() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": ["content-type", 1, NSNull()]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
    }

    // MARK: - Equatable

    func testEquality_sameModeAndTerms_shouldBeEqual() {
        let a: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["auth"])
        let b: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["auth"])
        XCTAssertEqual(a, b)
    }

    func testEquality_differentModes_shouldNotBeEqual() {
        XCTAssertNotEqual(
            SentryDataCollection.KeyValueCollectionBehavior.denyList(),
            SentryDataCollection.KeyValueCollectionBehavior.off
        )
    }

    func testEquality_differentTerms_shouldNotBeEqual() {
        XCTAssertNotEqual(
            SentryDataCollection.KeyValueCollectionBehavior.denyList(terms: ["a"]),
            SentryDataCollection.KeyValueCollectionBehavior.denyList(terms: ["b"])
        )
    }
}
