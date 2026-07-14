@testable import Sentry
import XCTest

final class SentryKeyValueFilterTests: XCTestCase {

    func testFilter_whenBehaviorIsOff_shouldReturnEmptyDictionary() {
        // -- Arrange --
        let values = ["Content-Type": "application/json"]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(values, behavior: .off)

        // -- Assert --
        XCTAssertEqual(result, [:])
    }

    func testFilter_whenDenyListUsesBuiltInTerms_shouldFilterSensitiveValues() {
        // -- Arrange --
        let values = [
            "Authorization": "Bearer abc123",
            "Content-Type": "application/json",
            "X-Api-Key": "secret-key-value"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(values, behavior: .denyList())

        // -- Assert --
        XCTAssertEqual(result, [
            "Authorization": "[Filtered]",
            "Content-Type": "application/json",
            "X-Api-Key": "[Filtered]"
        ])
    }

    func testFilter_whenDenyListHasCustomTerms_shouldFilterMatchingValues() {
        // -- Arrange --
        let values = [
            "Content-Type": "application/json",
            "X-Forwarded-For": "192.0.2.1"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(
            values,
            behavior: .denyList(terms: ["FORWARDED"])
        )

        // -- Assert --
        XCTAssertEqual(result, [
            "Content-Type": "application/json",
            "X-Forwarded-For": "[Filtered]"
        ])
    }

    func testFilter_whenAllowListHasTerms_shouldOnlyKeepMatchingValues() {
        // -- Arrange --
        let values = [
            "Content-Type": "application/json",
            "X-Custom": "custom",
            "X-Request-Id": "12345"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(
            values,
            behavior: .allowList(terms: ["CONTENT", "request"])
        )

        // -- Assert --
        XCTAssertEqual(result, [
            "Content-Type": "application/json",
            "X-Custom": "[Filtered]",
            "X-Request-Id": "12345"
        ])
    }

    func testFilter_whenAllowListContainsSensitiveKey_shouldFilterSensitiveValue() {
        // -- Arrange --
        let values = [
            "Authorization": "Bearer abc123",
            "Content-Type": "application/json"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(
            values,
            behavior: .allowList(terms: ["authorization", "content-type"])
        )

        // -- Assert --
        XCTAssertEqual(result, [
            "Authorization": "[Filtered]",
            "Content-Type": "application/json"
        ])
    }

    func testFilter_whenKeyPartiallyMatchesTermWithDifferentCase_shouldFilterValue() {
        // -- Arrange --
        let values = ["My-Custom-HeAdEr": "value"]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(
            values,
            behavior: .denyList(terms: ["CUSTOM-header"])
        )

        // -- Assert --
        XCTAssertEqual(result, ["My-Custom-HeAdEr": "[Filtered]"])
    }

    func testFilter_whenFilteringValues_shouldPreserveKeyNames() {
        // -- Arrange --
        let values = [
            "Authorization": "Bearer abc123",
            "Content-Type": "application/json",
            "X-Request-Id": "12345"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(
            values,
            behavior: .allowList(terms: ["content-type"])
        )

        // -- Assert --
        XCTAssertEqual(Set(result.keys), Set(values.keys))
    }

    func testFilter_whenKeyMatchesCanonicalSensitiveTerm_shouldFilterValue() {
        // -- Arrange --
        let sensitiveTerms = [
            "auth", "token", "secret", "password", "passwd", "pwd", "key", "jwt", "bearer",
            "sso", "saml", "csrf", "xsrf", "credentials", "session", "sid", "identity"
        ]
        let values = Dictionary(uniqueKeysWithValues: sensitiveTerms.map { term in
            ("prefix-\(term)-suffix", term)
        })

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(values, behavior: .denyList())

        // -- Assert --
        XCTAssertEqual(result, values.mapValues { _ in "[Filtered]" })
    }

    func testFilter_whenValuesAreEmpty_shouldReturnEmptyDictionaryForEveryBehavior() {
        // -- Arrange --
        let behaviors: [SentryDataCollection.KeyValueCollectionBehavior] = [
            .off,
            .denyList(),
            .allowList(terms: ["content-type"])
        ]

        for behavior in behaviors {
            // -- Act --
            let result = SentryDataCollection.KeyValueFilter.filter([:], behavior: behavior)

            // -- Assert --
            XCTAssertEqual(result, [:])
        }
    }

    func testFilter_whenDenyListTermsAreEmpty_shouldApplyBuiltInTerms() {
        // -- Arrange --
        let values = [
            "Authorization": "Bearer abc123",
            "Content-Type": "application/json"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(values, behavior: .denyList(terms: []))

        // -- Assert --
        XCTAssertEqual(result, [
            "Authorization": "[Filtered]",
            "Content-Type": "application/json"
        ])
    }

    func testFilter_whenAllowListTermsAreEmpty_shouldFilterEveryValue() {
        // -- Arrange --
        let values = [
            "Authorization": "Bearer abc123",
            "Content-Type": "application/json"
        ]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(values, behavior: .allowList(terms: []))

        // -- Assert --
        XCTAssertEqual(result, [
            "Authorization": "[Filtered]",
            "Content-Type": "[Filtered]"
        ])
    }
}
