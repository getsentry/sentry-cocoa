@_spi(Private) @testable import Sentry
import XCTest

class SentryKeyValueCollectionBehaviorTests: XCTestCase {

    // MARK: - Defaults

    func testOff() {
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .off

        // -- Assert --
        XCTAssertEqual(behavior, .off)
    }

    func testDenyList_withoutTerms_shouldHaveEmptyTerms() {
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .denyList()

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: []))
    }

    func testDenyList_withTerms_shouldStoreTerms() {
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["x-custom", "secret"])

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom", "secret"]))
    }

    func testAllowList_shouldStoreTerms() {
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .allowList(terms: ["content-type"])

        // -- Assert --
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

    func testInitWithDictionary_whenModeHasWrongType_shouldDefaultToDenyList() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": 1]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldDefaultToDenyList() {
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
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

    func testInitWithDictionary_whenTermsAreMissingForDenyList_shouldUseEmptyTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "denyList"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
    }

    func testInitWithDictionary_whenTermsAreMissingForAllowList_shouldUseEmptyTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
    }

    func testInitWithDictionary_whenTermsAreEmpty_shouldUseEmptyTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": []]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
    }

    func testInitWithDictionary_whenTermsHaveWrongType_shouldUseEmptyTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": "content-type"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
    }

    func testInitWithDictionary_whenTermsAreNSNull_shouldUseEmptyTerms() {
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": NSNull()]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
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
        // -- Arrange --
        let a: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["auth"])
        let b: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["auth"])

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertTrue(isEqual)
    }

    func testEquality_differentModes_shouldNotBeEqual() {
        // -- Arrange --
        let a = SentryDataCollection.KeyValueCollectionBehavior.denyList()
        let b = SentryDataCollection.KeyValueCollectionBehavior.off

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
    }

    func testEquality_differentTerms_shouldNotBeEqual() {
        // -- Arrange --
        let a = SentryDataCollection.KeyValueCollectionBehavior.denyList(terms: ["a"])
        let b = SentryDataCollection.KeyValueCollectionBehavior.denyList(terms: ["b"])

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
    }
}
