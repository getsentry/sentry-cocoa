@_spi(Private) @testable import Sentry
import XCTest

final class SentryHttpStatusCodeTests: XCTestCase {

    // MARK: - Int == SentryHttpStatusCode Tests

    func testIntEqualsEnum_whenValuesMatch_shouldReturnTrue() {
        XCTAssertTrue(413 == SentryHttpStatusCode.contentTooLarge)
    }

    func testIntEqualsEnum_whenValuesDontMatch_shouldReturnFalse() {
        XCTAssertFalse(200 == SentryHttpStatusCode.contentTooLarge)
    }

    // MARK: - SentryHttpStatusCode == Int Tests

    func testEnumEqualsInt_whenValuesMatch_shouldReturnTrue() {
        XCTAssertTrue(SentryHttpStatusCode.contentTooLarge == 413)
    }

    func testEnumEqualsInt_whenValuesDontMatch_shouldReturnFalse() {
        XCTAssertFalse(SentryHttpStatusCode.contentTooLarge == 200)
    }

    // MARK: - Raw Value Tests

    func testRawValue_whenOk_shouldReturn200() {
        XCTAssertEqual(SentryHttpStatusCode.ok.rawValue, 200)
    }

    func testRawValue_whenCreated_shouldReturn201() {
        XCTAssertEqual(SentryHttpStatusCode.created.rawValue, 201)
    }

    func testRawValue_whenBadRequest_shouldReturn400() {
        XCTAssertEqual(SentryHttpStatusCode.badRequest.rawValue, 400)
    }

    func testRawValue_whenContentTooLarge_shouldReturn413() {
        XCTAssertEqual(SentryHttpStatusCode.contentTooLarge.rawValue, 413)
    }

    func testRawValue_whenPreconditionFailed_shouldReturn412() {
        XCTAssertEqual(SentryHttpStatusCode.preconditionFailed.rawValue, 412)
    }

    func testRawValue_whenTooManyRequests_shouldReturn429() {
        XCTAssertEqual(SentryHttpStatusCode.tooManyRequests.rawValue, 429)
    }

    func testRawValue_whenInternalServerError_shouldReturn500() {
        XCTAssertEqual(SentryHttpStatusCode.internalServerError.rawValue, 500)
    }
}
