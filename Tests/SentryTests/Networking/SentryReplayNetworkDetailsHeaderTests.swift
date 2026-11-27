@_spi(Private) @testable import Sentry
import XCTest

class SentryReplayNetworkDetailsHeaderTests: XCTestCase {

    // MARK: - Header Extraction Tests

    func testExtractHeaders_caseInsensitiveMatching() {
        // -- Arrange --
        let sourceHeaders: [String: Any] = [
            "Content-Type": "application/json",
            "AUTHORIZATION": "Bearer token",
            "x-request-id": "123"
        ]
        let configuredHeaders = ["content-type", "Authorization", "X-Request-ID"]

        // -- Act --
        let extracted = SentryReplayNetworkDetails.extractHeaders(
            from: sourceHeaders,
            matching: configuredHeaders
        )

        // -- Assert --
        XCTAssertEqual(extracted.count, 3)
        // Should preserve original casing from source
        XCTAssertEqual(extracted["Content-Type"], "application/json")
        XCTAssertEqual(extracted["AUTHORIZATION"], "Bearer token")
        XCTAssertEqual(extracted["x-request-id"], "123")
    }

    func testExtractHeaders_withNilInputs_returnsEmptyDict() {
        // Test nil source headers
        XCTAssertEqual(
            SentryReplayNetworkDetails.extractHeaders(from: nil, matching: ["test"]),
            [:]
        )

        // Test nil configured headers
        XCTAssertEqual(
            SentryReplayNetworkDetails.extractHeaders(from: ["test": "value"], matching: nil),
            [:]
        )

        // Test both nil
        XCTAssertEqual(
            SentryReplayNetworkDetails.extractHeaders(from: nil, matching: nil),
            [:]
        )
    }

    func testExtractHeaders_nonStringValues_convertedToStrings() {
        // -- Arrange --
        let sourceHeaders: [String: Any] = [
            "Content-Length": NSNumber(value: 9_876),
            "Retry-After": 60,
            "X-Bool": true,
            "X-Double": 3.14159
        ]
        let configuredHeaders = ["Content-Length", "Retry-After", "X-Bool", "X-Double"]

        // -- Act --
        let extracted = SentryReplayNetworkDetails.extractHeaders(
            from: sourceHeaders,
            matching: configuredHeaders
        )

        // -- Assert --
        XCTAssertEqual(extracted.count, 4)
        XCTAssertEqual(extracted["Content-Length"], "9876")
        XCTAssertEqual(extracted["Retry-After"], "60")
        XCTAssertEqual(extracted["X-Bool"], "true")
        XCTAssertEqual(extracted["X-Double"], "3.14159")
    }

    func testExtractHeaders_unconfiguredHeadersAreExcluded() {
        // -- Arrange --
        let sourceHeaders: [String: Any] = [
            "Content-Type": "application/json",
            "Authorization": "Bearer token",
            "X-Custom": "should not appear"
        ]
        let configuredHeaders = ["Content-Type", "Authorization"]

        // -- Act --
        let extracted = SentryReplayNetworkDetails.extractHeaders(
            from: sourceHeaders,
            matching: configuredHeaders
        )

        // -- Assert --
        XCTAssertEqual(extracted.count, 2)
        XCTAssertEqual(extracted["Content-Type"], "application/json")
        XCTAssertEqual(extracted["Authorization"], "Bearer token")
        XCTAssertNil(extracted["X-Custom"])
    }
}
