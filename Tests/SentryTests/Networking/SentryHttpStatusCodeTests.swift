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
        XCTAssertTrue(SentryHttpStatusCode.ok == 200)
    }

    func testStatusCodeValue_whenCreated_shouldBe201() {
        XCTAssertTrue(SentryHttpStatusCode.created == 201)
    }

    func testStatusCodeValue_whenBadRequest_shouldBe400() {
        XCTAssertTrue(SentryHttpStatusCode.badRequest == 400)
    }

    func testStatusCodeValue_whenPreconditionFailed_shouldBe412() {
        XCTAssertTrue(SentryHttpStatusCode.preconditionFailed == 412)
    }

    func testStatusCodeValue_whenContentTooLarge_shouldBe413() {
        XCTAssertTrue(SentryHttpStatusCode.contentTooLarge == 413)
    }

    func testStatusCodeValue_whenTooManyRequests_shouldBe429() {
        XCTAssertTrue(SentryHttpStatusCode.tooManyRequests == 429)
    }

    func testStatusCodeValue_whenInternalServerError_shouldBe500() {
        XCTAssertTrue(SentryHttpStatusCode.internalServerError == 500)
    }

    // MARK: - Raw Value Test

    func testRawValue_shouldReturnCorrectInt() {
        XCTAssertEqual(SentryHttpStatusCode.contentTooLarge.rawValue, 413)
    }
}
