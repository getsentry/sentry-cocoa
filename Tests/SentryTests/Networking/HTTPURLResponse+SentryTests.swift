@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class HTTPURLResponseSentryTests: XCTestCase {

    // MARK: - value(forHTTPHeaderFieldCaseInsensitive:)

    func testValueForHTTPHeaderFieldCaseInsensitive_whenLowercaseResponseAndUppercaseName_returnsValue() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        let value = response.value(forHTTPHeaderFieldCaseInsensitive: "X-Sentry-Rate-Limits")

        // -- Assert --
        XCTAssertEqual(value, "60:replay:organization:replay_usage_exceeded")
    }

    func testValueForHTTPHeaderFieldCaseInsensitive_whenCanonicalResponseAndLowercaseName_returnsValue() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponseHTTP1_1(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        let value = response.value(forHTTPHeaderFieldCaseInsensitive: "x-sentry-rate-limits")

        // -- Assert --
        XCTAssertEqual(value, "60:replay:organization:replay_usage_exceeded")
    }

    func testValueForHTTPHeaderFieldCaseInsensitive_whenHeaderMissing_returnsNil() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["some-other-header": "value"]))

        // -- Act --
        let value = response.value(forHTTPHeaderFieldCaseInsensitive: "x-sentry-rate-limits")

        // -- Assert --
        XCTAssertNil(value)
    }

    // MARK: - sentryCaseInsensitiveHeaderValue (pre-macOS-10.15 fallback)

    /// The fallback runs on macOS < 10.15, which our tests never run on, so we exercise it directly.
    /// Looking up an uppercase name must find a header the server sent lowercase.
    func testCaseInsensitiveHeaderValueFallback_whenLowercaseResponseAndUppercaseName_returnsValue() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        let value = response.sentryCaseInsensitiveHeaderValue(forName: "X-Sentry-Rate-Limits")

        // -- Assert --
        XCTAssertEqual(value, "60:replay:organization:replay_usage_exceeded")
    }

    /// Looking up a lowercase name must find a header the server sent in the conventional casing.
    func testCaseInsensitiveHeaderValueFallback_whenCanonicalResponseAndLowercaseName_returnsValue() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponseHTTP1_1(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        let value = response.sentryCaseInsensitiveHeaderValue(forName: "x-sentry-rate-limits")

        // -- Assert --
        XCTAssertEqual(value, "60:replay:organization:replay_usage_exceeded")
    }

    /// The scan compares keys case-insensitively, so even an unconventional mixed casing resolves.
    func testCaseInsensitiveHeaderValueFallback_whenMixedCaseResponseKey_returnsValue() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["X-SeNtRy-RaTe-LiMiTs": "60:replay:organization:replay_usage_exceeded"]))

        // -- Act --
        let value = response.sentryCaseInsensitiveHeaderValue(forName: "x-sentry-rate-limits")

        // -- Assert --
        XCTAssertEqual(value, "60:replay:organization:replay_usage_exceeded")
    }

    func testCaseInsensitiveHeaderValueFallback_whenHeaderMissing_returnsNil() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["some-other-header": "value"]))

        // -- Act --
        let value = response.sentryCaseInsensitiveHeaderValue(forName: "x-sentry-rate-limits")

        // -- Assert --
        XCTAssertNil(value)
    }

    // MARK: - SentryHTTPHeaderReader (Objective-C bridge)

    func testHTTPHeaderReader_forwardsToCaseInsensitiveLookup() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        let value = HTTPHeaderReader.value(forHTTPHeaderFieldCaseInsensitive: "X-Sentry-Rate-Limits", in: response)

        // -- Assert --
        XCTAssertEqual(value, "60:replay:organization:replay_usage_exceeded")
    }
}
