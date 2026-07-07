@testable import Sentry
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
