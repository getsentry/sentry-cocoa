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

    // MARK: - Status Code Value Tests

    func testStatusCodeValue_whenOk_shouldBe200() {
        XCTAssertTrue(200 == SentryHttpStatusCode.ok)
    }

    func testStatusCodeValue_whenCreated_shouldBe201() {
        XCTAssertTrue(201 == SentryHttpStatusCode.created)
    }

    func testStatusCodeValue_whenBadRequest_shouldBe400() {
        XCTAssertTrue(400 == SentryHttpStatusCode.badRequest)
    }

    func testStatusCodeValue_whenPreconditionFailed_shouldBe412() {
        XCTAssertTrue(412 == SentryHttpStatusCode.preconditionFailed)
    }

    func testStatusCodeValue_whenContentTooLarge_shouldBe413() {
        XCTAssertTrue(413 == SentryHttpStatusCode.contentTooLarge)
    }

    func testStatusCodeValue_whenTooManyRequests_shouldBe429() {
        XCTAssertTrue(429 == SentryHttpStatusCode.tooManyRequests)
    }

    func testStatusCodeValue_whenInternalServerError_shouldBe500() {
        XCTAssertTrue(500 == SentryHttpStatusCode.internalServerError)
    }

    // MARK: - Raw Value Test

    func testRawValue_shouldReturnCorrectInt() {
        XCTAssertEqual(SentryHttpStatusCode.contentTooLarge.rawValue, 413)
    }
}
