@_spi(Private) @testable import Sentry
import Foundation
import XCTest

final class UrlSanitizedTests: XCTestCase {

    private func createSUT(url: URL) -> UrlSanitized {
        #if SDK_V10
        UrlSanitized(URL: url, options: SentryDataCollection.Options())
        #else
        UrlSanitized(URL: url)
        #endif
    }

    func testInit_whenURLHasNoQueryOrFragment_shouldReturnSanitizedURL() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedUrl, "http://sentry.io")
    }

    func testInit_whenURLHasQueryAndFragment_shouldSeparateComponents() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io?query=value&query2=value2#fragment")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(sut.sanitizedUrl, "http://sentry.io?query=value&query2=value2")
#else
        XCTAssertEqual(sut.sanitizedUrl, "http://sentry.io")
#endif // SDK_V10
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io")
        XCTAssertEqual(sut.query, "query=value&query2=value2")
        XCTAssertEqual(sut.fragment, "fragment")
    }

    func testSanitizedUrl_whenRemovingComponents_shouldNotModifyStoredComponents() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io?query=value#fragment")!
        let sut = createSUT(url: url)

        // -- Act --
        let sanitizedUrl = sut.sanitizedUrl

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(sanitizedUrl, "http://sentry.io?query=value")
#else
        XCTAssertEqual(sanitizedUrl, "http://sentry.io")
#endif // SDK_V10
        XCTAssertEqual(sut.query, "query=value")
        XCTAssertEqual(sut.fragment, "fragment")
    }

    func testSanitizedBaseUrl_whenURLHasNoQueryOrFragment_shouldReturnFullURL() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io")
    }

    func testSanitizedBaseUrl_whenURLHasQuery_shouldRemoveQuery() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io?query=value")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io")
    }

    func testSanitizedBaseUrl_whenURLHasFragment_shouldRemoveFragment() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io#fragment")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io")
    }

    func testSanitizedBaseUrl_whenURLHasQueryAndFragment_shouldRemoveBoth() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io?query=value#fragment")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io")
    }

    func testSanitizedBaseUrl_whenFragmentContainsQuery_shouldRemoveFragment() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io#/users?id=1")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io")
    }

    func testSanitizedUrl_whenPercentEncodingIsInvalid_shouldPreserveEncodedURL() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io/%FF")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedUrl, "http://sentry.io/%FF")
    }

    func testSanitizedBaseUrl_whenPercentEncodingIsInvalid_shouldPreserveEncodedURL() {
        // -- Arrange --
        let url = URL(string: "http://sentry.io/%FF")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://sentry.io/%FF")
    }

    func testSanitizedBaseUrl_whenURLHasCredentials_shouldFilterCredentials() {
        // -- Arrange --
        let url = URL(string: "http://User:Password@sentry.io?query=value#fragment")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedBaseUrl, "http://[Filtered]:[Filtered]@sentry.io")
    }

    func testInit_whenURLHasUserAndPassword_shouldFilterCredentials() {
        // -- Arrange --
        let url = URL(string: "http://User:Password@sentry.io")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
        XCTAssertEqual(sut.sanitizedUrl, "http://[Filtered]:[Filtered]@sentry.io")
    }

    func testInit_whenURLHasUserPasswordAndQuery_shouldFilterOnlyCredentialsInSanitizedURL() {
        // -- Arrange --
        let url = URL(string: "http://User:Password@sentry.io?query=value")!

        // -- Act --
        let sut = createSUT(url: url)

        // -- Assert --
#if SDK_V10
        XCTAssertEqual(sut.sanitizedUrl, "http://[Filtered]:[Filtered]@sentry.io?query=value")
#else
        XCTAssertEqual(sut.sanitizedUrl, "http://[Filtered]:[Filtered]@sentry.io")
#endif // SDK_V10
        XCTAssertEqual(sut.query, "query=value")
    }

    func testInit_whenQueryUsesDefaultDenyList_shouldFilterSensitiveValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?token=abc&page=2")!
        let options = SentryDataCollection.Options()

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "token=[Filtered]&page=2")
        #endif
    }

    func testInit_whenQueryUsesCustomDenyList_shouldFilterMatchingValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?email=user@example.com&page=2")!
        let options = SentryDataCollection.Options(urlQueryParams: .denyList(terms: ["email"]))

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "email=[Filtered]&page=2")
        #endif
    }

    func testInit_whenQueryCollectionIsOff_shouldRemoveQuery() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?query=value")!
        let options = SentryDataCollection.Options(urlQueryParams: .off)

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertNil(sut.query)
        XCTAssertNil(sut.queryItems)
        XCTAssertEqual(sut.sanitizedUrl, "http://sentry.io")
        #endif
    }

    func testInit_whenQueryUsesAllowList_shouldOnlyKeepAllowedValues() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?page=2&sort=asc&token=abc")!
        let options = SentryDataCollection.Options(
            urlQueryParams: .allowList(terms: ["page", "token"])
        )

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "page=2&sort=[Filtered]&token=[Filtered]")
        #endif
    }

    func testInit_whenQueryContainsRepeatedKeys_shouldPreserveEveryItem() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?token=abc&token=def&page=2")!
        let options = SentryDataCollection.Options()

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "token=[Filtered]&token=[Filtered]&page=2")
        XCTAssertEqual(sut.queryItems?.count, 3)
        #endif
    }

    func testInit_whenQueryContainsValuelessItem_shouldPreserveIt() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?debug&other")!
        let options = SentryDataCollection.Options(urlQueryParams: .allowList(terms: ["debug"]))

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "debug&other=[Filtered]")
        #endif
    }

    func testInit_whenQueryContainsPercentEncodedValues_shouldReconstructQuery() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?search=hello%20world&redirect=a%26b")!
        let options = SentryDataCollection.Options()

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "search=hello world&redirect=a&b")
        #endif
    }

    func testInit_whenQueryIsUnparseable_shouldFilterEntireQuery() throws {
        #if !SDK_V10
        throw XCTSkip("Test skipped for SDK_V10")
        #else
        // -- Arrange --
        let url = URL(string: "http://sentry.io?query=%FF")!
        let options = SentryDataCollection.Options()

        // -- Act --
        let sut = UrlSanitized(URL: url, options: options)

        // -- Assert --
        XCTAssertEqual(sut.query, "[Filtered]")
        #endif
    }
}
