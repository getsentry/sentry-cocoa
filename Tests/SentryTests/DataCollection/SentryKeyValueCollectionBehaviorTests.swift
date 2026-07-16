@_spi(Private) @testable import Sentry
import XCTest

class SentryKeyValueCollectionBehaviorTests: XCTestCase {

    // MARK: - Defaults

    func testOff() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .off

        // -- Assert --
        XCTAssertEqual(behavior, .off)
        #endif
    }

    func testDenyList_withoutTerms_shouldHaveEmptyTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .denyList()

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: []))
        #endif
    }

    func testDenyList_withTerms_shouldStoreTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["x-custom", "secret"])

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom", "secret"]))
        #endif
    }

    func testAllowList_shouldStoreTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Act --
        let behavior: SentryDataCollection.KeyValueCollectionBehavior = .allowList(terms: ["content-type"])

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenModeIsOff_shouldReturnOff() {
               #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "off"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .off)
        #endif
    }

    func testInitWithDictionary_whenModeIsDenyListWithTerms_shouldReturnDenyListWithTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "denyList", "terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom"]))
        #endif
    }

    func testInitWithDictionary_whenModeIsAllowListWithTerms_shouldReturnAllowListWithTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": ["content-type"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
        #endif
    }

    func testInitWithDictionary_whenModeIsMissing_shouldDefaultToDenyList() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom"]))
        #endif
    }

    func testInitWithDictionary_whenModeHasWrongType_shouldDefaultToDenyList() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": 1]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldDefaultToDenyList() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenModeIsUnknown_shouldDefaultToDenyList() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "unknown", "terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenModeIsNSNull_shouldDefaultToDenyList() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": NSNull()]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenTermsAreMissingForDenyList_shouldUseEmptyTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "denyList"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenTermsAreMissingForAllowList_shouldUseEmptyTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsAreEmpty_shouldUseEmptyTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": []]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsHaveWrongType_shouldUseEmptyTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": "content-type"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsAreNSNull_shouldUseEmptyTerms() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": NSNull()]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsContainsNonStrings_shouldIgnoreNonStrings() {
                #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": ["content-type", 1, NSNull()]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
        #endif
    }

    // MARK: - Dictionary Init

    func testInitWithDictionary_whenModeIsOff_shouldReturnOff() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "off"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .off)
        #endif
    }

    func testInitWithDictionary_whenModeIsDenyListWithTerms_shouldReturnDenyListWithTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "denyList", "terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom"]))
        #endif
    }

    func testInitWithDictionary_whenModeIsAllowListWithTerms_shouldReturnAllowListWithTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": ["content-type"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
        #endif
    }

    func testInitWithDictionary_whenModeIsMissing_shouldDefaultToDenyList() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList(terms: ["x-custom"]))
        #endif
    }

    func testInitWithDictionary_whenModeHasWrongType_shouldDefaultToDenyList() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": 1]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenDictionaryIsEmpty_shouldDefaultToDenyList() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = [:]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenModeIsUnknown_shouldDefaultToDenyList() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "unknown", "terms": ["x-custom"]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenModeIsNSNull_shouldDefaultToDenyList() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": NSNull()]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenTermsAreMissingForDenyList_shouldUseEmptyTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "denyList"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .denyList())
        #endif
    }

    func testInitWithDictionary_whenTermsAreMissingForAllowList_shouldUseEmptyTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsAreEmpty_shouldUseEmptyTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": []]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsHaveWrongType_shouldUseEmptyTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": "content-type"]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsAreNSNull_shouldUseEmptyTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": NSNull()]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: []))
        #endif
    }

    func testInitWithDictionary_whenTermsContainsNonStrings_shouldIgnoreNonStrings() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let dictionary: [String: Any] = ["mode": "allowList", "terms": ["content-type", 1, NSNull()]]

        // -- Act --
        let behavior = SentryDataCollection.KeyValueCollectionBehavior(dictionary: dictionary)

        // -- Assert --
        XCTAssertEqual(behavior, .allowList(terms: ["content-type"]))
        #endif
    }

    // MARK: - Equatable

    func testEquality_sameModeAndTerms_shouldBeEqual() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let a: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["auth"])
        let b: SentryDataCollection.KeyValueCollectionBehavior = .denyList(terms: ["auth"])

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertTrue(isEqual)
        #endif
    }

    func testEquality_differentModes_shouldNotBeEqual() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let a = SentryDataCollection.KeyValueCollectionBehavior.denyList()
        let b = SentryDataCollection.KeyValueCollectionBehavior.off

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
        #endif
    }

    func testEquality_differentTerms_shouldNotBeEqual() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let a = SentryDataCollection.KeyValueCollectionBehavior.denyList(terms: ["a"])
        let b = SentryDataCollection.KeyValueCollectionBehavior.denyList(terms: ["b"])

        // -- Act --
        let isEqual = a == b

        // -- Assert --
        XCTAssertFalse(isEqual)
        #endif
    }
}
