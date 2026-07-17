@_spi(Private) @testable import Sentry
import XCTest

final class HTTPHeaderSanitizerTests: XCTestCase {

    func testSanitizeHeaders_whenDefaultBehavior_shouldApplyVersionSpecificFiltering() {
        // -- Arrange --
        let headers = [
            "Authorization": "Bearer secret",
            "Content-Type": "application/json",
            "X-Api-Key": "api-key"
        ]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .off
        )

        XCTAssertEqual(result.headers, [
            "Authorization": "[Filtered]",
            "Content-Type": "application/json",
            "X-Api-Key": "[Filtered]"
        ])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), ["Content-Type": "application/json"])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenOptionsArePassed_shouldUseDirectionSpecificHeaderBehavior() {
        // -- Arrange --
        let headers = ["X-Request-Id": "request-id"]

        // -- Act & Assert --
#if SDK_V10
        let options = SentryDataCollection.Options(
            httpHeaders: .init(
                request: .off,
                response: .denyList()
            )
        )

        let requestResult: HTTPHeaderSanitizer.SanitizedHeaders =
            HTTPHeaderSanitizer.sanitizeRequestHeaders(headers, options: options)
        let responseResult: HTTPHeaderSanitizer.SanitizedHeaders =
            HTTPHeaderSanitizer.sanitizeResponseHeaders(headers, options: options)
        let objcOptions = SentryDataCollectionObjCOptions(wrapped: options)
        let objcRequestResult = HTTPHeaderSanitizerObjC.sanitizeRequestHeaders(
            headers,
            options: objcOptions
        )
        let objcResponseResult = HTTPHeaderSanitizerObjC.sanitizeResponseHeaders(
            headers,
            options: objcOptions
        )

        XCTAssertEqual(requestResult.headers, [:])
        XCTAssertEqual(responseResult.headers, headers)
        XCTAssertEqual(objcRequestResult.headers, requestResult.headers)
        XCTAssertEqual(objcRequestResult.cookies, requestResult.cookies)
        XCTAssertEqual(objcResponseResult.headers, responseResult.headers)
        XCTAssertEqual(objcResponseResult.cookies, responseResult.cookies)
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), headers)
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenHeaderCollectionIsOffAndCookiesAreEnabled_shouldCollectOnlyCookies() {
        // -- Arrange --
        let headers = [
            "Content-Type": "application/json",
            "Cookie": "theme=dark; session=secret"
        ]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, [:])
        XCTAssertEqual(result.cookies, ["theme": "dark", "session": "[Filtered]"])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), ["Content-Type": "application/json"])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieCollectionIsOffAndHeadersAreEnabled_shouldCollectOnlyOrdinaryHeaders() {
        // -- Arrange --
        let headers = [
            "Content-Type": "application/json",
            "Cookie": "theme=dark"
        ]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .off
        )

        XCTAssertEqual(result.headers, ["Content-Type": "application/json"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), ["Content-Type": "application/json"])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenHeaderDenyListHasCustomTerm_shouldFilterMatchingValue() {
        // -- Arrange --
        let headers = ["X-Forwarded-For": "192.0.2.1", "Content-Type": "application/json"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(terms: ["forwarded"]),
            cookieBehavior: .off
        )

        XCTAssertEqual(result.headers, [
            "X-Forwarded-For": "[Filtered]",
            "Content-Type": "application/json"
        ])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), ["Content-Type": "application/json"])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenHeaderAllowListIsConfigured_shouldFilterNonAllowedValues() {
        // -- Arrange --
        let headers = [
            "Content-Type": "application/json",
            "X-Request-Id": "request-id",
            "Authorization": "Bearer secret"
        ]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .allowList(terms: ["content-type", "authorization"]),
            cookieBehavior: .off
        )

        XCTAssertEqual(result.headers, [
            "Content-Type": "application/json",
            "X-Request-Id": "[Filtered]",
            "Authorization": "[Filtered]"
        ])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [
            "Content-Type": "application/json",
            "X-Request-Id": "request-id"
        ])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieAllowListIsConfigured_shouldFilterNonAllowedAndSensitiveValues() {
        // -- Arrange --
        let headers = ["Cookie": "theme=dark; locale=en; token=secret"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .allowList(terms: ["theme", "token"])
        )

        XCTAssertEqual(result.headers, [:])
        XCTAssertEqual(result.cookies, [
            "theme": "dark",
            "locale": "[Filtered]",
            "token": "[Filtered]"
        ])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieDenyListHasCustomTerm_shouldFilterMatchingValue() {
        // -- Arrange --
        let headers = ["Cookie": "theme=dark; tracking_id=abc"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList(terms: ["tracking"])
        )

        XCTAssertEqual(result.cookies, ["theme": "dark", "tracking_id": "[Filtered]"])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenSetCookieHasAttributes_shouldCollectOnlyCookiePair() {
        // -- Arrange --
        let headers = ["Set-Cookie": "theme=dark; Path=/; HttpOnly; Secure"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, [:])
        XCTAssertEqual(result.cookies, ["theme": "dark"])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenSetCookieIsSensitive_shouldFilterCookieValue() {
        // -- Arrange --
        let headers = ["Set-Cookie": "session=secret; HttpOnly"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.cookies, ["session": "[Filtered]"])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieIsUnparseable_shouldUseFilteredHeaderFallbackWhenHeadersEnabled() {
        // -- Arrange --
        let headers = ["Cookie": "theme"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, ["Cookie": "[Filtered]"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenSetCookieIsUnparseable_shouldUseFilteredHeaderFallbackWhenHeadersEnabled() {
        // -- Arrange --
        let headers = ["Set-Cookie": "theme; HttpOnly"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, ["Set-Cookie": "[Filtered]"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenInputIsEmpty_shouldReturnEmptyResult() {
        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            [:],
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, [:])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders([:]), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenMalformedCookieAndHeadersAreOff_shouldOmitFallback() {
        // -- Arrange --
        let headers = ["Cookie": "theme"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, [:])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieNameIsEmpty_shouldUseFilteredHeaderFallback() {
        // -- Arrange --
        let headers = ["Cookie": "=value"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, ["Cookie": "[Filtered]"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieValueIsEmpty_shouldPreserveEmptyValue() {
        // -- Arrange --
        let headers = ["Cookie": "theme="]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.cookies, ["theme": ""])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieValueContainsEqualsSigns_shouldSplitOnlyAtFirstEqualsSign() {
        // -- Arrange --
        let headers = ["Cookie": "data=base64==; theme=dark"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.cookies, ["data": "base64==", "theme": "dark"])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieContainsWhitespaceOnlySegment_shouldUseFilteredHeaderFallback() {
        // -- Arrange --
        let headers = ["Cookie": "theme=dark; ; locale=en"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, ["Cookie": "[Filtered]"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieHeaderIsEmpty_shouldUseFilteredHeaderFallback() {
        // -- Arrange --
        let headers = ["Cookie": ""]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, ["Cookie": "[Filtered]"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenSetCookieHeaderIsEmpty_shouldUseFilteredHeaderFallback() {
        // -- Arrange --
        let headers = ["Set-Cookie": ""]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.headers, ["Set-Cookie": "[Filtered]"])
        XCTAssertEqual(result.cookies, [:])
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }

    func testSanitizeHeaders_whenCookieNamesRepeatAcrossHeaders_shouldKeepOneValue() {
        // -- Arrange --
        let headers = ["Cookie": "theme=dark", "Set-Cookie": "theme=light; HttpOnly"]

        // -- Act & Assert --
#if SDK_V10
        let result = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .off,
            cookieBehavior: .denyList()
        )

        XCTAssertEqual(result.cookies.count, 1)
        XCTAssertTrue(result.cookies["theme"] == "dark" || result.cookies["theme"] == "light")
#else
        XCTAssertEqual(HTTPHeaderSanitizer.sanitizeHeaders(headers), [:])
#endif // SDK_V10
    }
}
