@testable import Sentry
import XCTest

final class SentryKeyValueFilterTests: XCTestCase {

    func testFilter_whenBehaviorIsOff_shouldReturnEmptyDictionary() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let values = ["Content-Type": "application/json"]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(values, behavior: .off)

        // -- Assert --
        XCTAssertEqual(result, [:])
        #endif
    }

    func testFilter_whenDenyListUsesBuiltInTerms_shouldFilterSensitiveValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenDenyListHasCustomTerms_shouldFilterMatchingValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenAllowListHasTerms_shouldOnlyKeepMatchingValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenAllowListContainsSensitiveKey_shouldFilterSensitiveValue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenKeyPartiallyMatchesTermWithDifferentCase_shouldFilterValue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let values = ["My-Custom-HeAdEr": "value"]

        // -- Act --
        let result = SentryDataCollection.KeyValueFilter.filter(
            values,
            behavior: .denyList(terms: ["CUSTOM-header"])
        )

        // -- Assert --
        XCTAssertEqual(result, ["My-Custom-HeAdEr": "[Filtered]"])
        #endif
    }

    func testFilter_whenFilteringValues_shouldPreserveKeyNames() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenKeyMatchesCanonicalSensitiveTerm_shouldFilterValue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenValuesAreEmpty_shouldReturnEmptyDictionaryForEveryBehavior() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenDenyListTermsAreEmpty_shouldApplyBuiltInTerms() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }

    func testFilter_whenAllowListTermsAreEmpty_shouldFilterEveryValue() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
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
        #endif
    }
}
