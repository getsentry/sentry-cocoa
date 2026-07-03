@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryDefaultRateLimitsTests: XCTestCase {
    
    private let defaultRetryAfterInSeconds = 60.0

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RateLimits!
    
    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
    
        sut = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: currentDateProvider), andRateLimitParser: RateLimitParser(currentDateProvider: currentDateProvider), currentDateProvider: currentDateProvider)
    }
    
    func testNoUpdateCalled() {
        // -- Arrange, Act & Assert --
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testRateLimitReached() throws {
        // -- Arrange --
        let category = SentryDataCategory.error
        XCTAssertFalse(sut.isRateLimitActive(category.rawValue))
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:error:key")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(category.rawValue))
        
        // Rate Limit almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(category.rawValue))
        
        // RateLimit expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(category.rawValue))
    }
    
    func testRateLimitAndRetryHeader() {
        // -- Arrange & Act --
        let category = SentryDataCategory.transaction
        if let response = HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: [
                "retry-after": "2",
                "x-sentry-rate-limits": "1:transaction:key"
        ]) {
            sut.update(response)
        }

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(category.rawValue))
        // If X-Sentry-Rate-Limits is set Retry-After is ignored
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        
        // Rate Limit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(category.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testRetryHeaderIn503() {
        // -- Arrange & Act --
        if let response = HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 503,
            httpVersion: "2.0",
            headerFields: [
                "retry-after": "2"
        ]) {
            sut.update(response)
        }

        // -- Assert --
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testRetryHeaderIsLikeAllCategories() throws {
        // -- Arrange & Act --
        sut.update(try TestResponseFactory.createRateLimitResponse(headerValue: "2::key"))
        sut.update(try TestResponseFactory.createRetryAfterResponse(headerValue: "3"))

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        
        // RateLimit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(3))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }

    func testRetryAfterHeaderDeltaSeconds() throws {
        // -- Arrange, Act & Assert --
        try assertRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() throws {
        // -- Arrange --
        let headerValue = HttpDateFormatter.string(from: currentDateProvider.date().addingTimeInterval(1))

        // -- Act & Assert --
        try assertRetryHeaderWith1Second(value: headerValue)
    }
    
    private func assertRetryHeaderWith1Second(value: String) throws {
        let response = try TestResponseFactory.createRetryAfterResponse(headerValue: value)
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.attachment.rawValue))
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testRetryAfterHeaderIsEmpty() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRetryAfterResponse(headerValue: "")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
    }
    
    func testLongerRetryHeaderIsKept() throws {
        // -- Arrange --
        let response11 = try TestResponseFactory.createRetryAfterResponse(headerValue: "11")
        let response10 = try TestResponseFactory.createRetryAfterResponse(headerValue: "10")

        // -- Act --
        sut.update(response11)
        sut.update(response10)

        // -- Assert --
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.99))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))

        let response1 = try TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        sut.update(response1)

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testLongerRateLimitIsKept() throws {
        // -- Arrange --
        let response11 = try TestResponseFactory.createRateLimitResponse(headerValue: "11:default;error:key")
        let response10 = try TestResponseFactory.createRateLimitResponse(headerValue: "10:default;error:key")

        // -- Act --
        sut.update(response11)
        sut.update(response10)

        // -- Assert --
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.99))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))

        let response1 = try TestResponseFactory.createRateLimitResponse(headerValue: "1:default;error:key")
        sut.update(response1)

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }
    
    func testAllCategories() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1::key")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))

        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.attachment.rawValue))
    }
    
    func testMetricBucket() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:::custom")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue), true)
    }
    
    func testMetricBucket_NoNamespace() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket::")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue), true)
    }
    
    func testMetricBucket_EmptyNamespace() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:::")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue), true)
    }
    
    func testMetricBucket_NamespaceExclusivelyThanOtherCustom() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:organization:quota_exceeded:customs;cust")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertFalse(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue))
    }
    
    func testMetricBucket_EmptyNamespaces() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:::;")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertFalse(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue))
    }
    
    func testIgnoreNamespaceForNonMetricBucket() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(headerValue: "1:error:::customs;cust")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.error.rawValue), true)
    }

    /// Reproduces https://github.com/getsentry/sentry-cocoa/issues/8322: relay returns a 429 whose
    /// lowercase `x-sentry-rate-limits` header scopes the limit to replay only. Before the fix the
    /// SDK missed the case-sensitive header, fell through to the generic 429 handling, and
    /// rate-limited every category. The status code matters: only a 429 triggers that fallthrough.
    func testUpdate_when429WithLowercaseRateLimitHeader_shouldOnlyRateLimitGivenCategory() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["x-sentry-rate-limits": "60:replay:organization:replay_usage_exceeded"]))

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))
        // The reported symptom: the generic-429 fallthrough wrongly limited these. `feedback`
        // represents every other category (equivalence partitioning); none may be limited.
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.feedback.rawValue))
    }

    /// A rate-limit header on a 200 response (the factory default) must also scope to the given
    /// category. This covers the "header on a successful response" case.
    func testUpdate_whenRateLimitHeaderLowercaseOverHTTP2_shouldOnlyRateLimitGivenCategory() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponse(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))
        // `error` represents every other category (equivalence partitioning); none may be limited.
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }

    /// Same behavior over HTTP/1.1, where the header name arrives in the conventional casing. It
    /// must behave identically, so it shares the exact same assertions as the HTTP/2 variant.
    func testUpdate_whenRateLimitHeaderCanonicalOverHTTP1_shouldOnlyRateLimitGivenCategory() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRateLimitResponseHTTP1_1(
            headerValue: "60:replay:organization:replay_usage_exceeded")

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))
        // `error` represents every other category (equivalence partitioning); none may be limited.
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }

    /// A 429 with only a `Retry-After` header (no rate-limit header) must back off all categories.
    /// Uses the default lowercase HTTP/2 factory.
    func testUpdate_whenRetryAfterOverHTTP2_shouldRateLimitAllCategories() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRetryAfterResponse(headerValue: "1")

        // -- Act --
        sut.update(response)

        // -- Assert --
        // `error` and `replay` represent all categories (equivalence partitioning).
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))

        // The 1-second Retry-After must have been parsed, not the 60-second default.
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }

    /// Same behavior over HTTP/1.1. It must behave identically, so it shares the exact same
    /// assertions as the HTTP/2 variant.
    func testUpdate_whenRetryAfterOverHTTP1_shouldRateLimitAllCategories() throws {
        // -- Arrange --
        let response = try TestResponseFactory.createRetryAfterResponseHTTP1_1(headerValue: "1")

        // -- Act --
        sut.update(response)

        // -- Assert --
        // `error` and `replay` represent all categories (equivalence partitioning).
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))

        // The 1-second Retry-After must have been parsed, not the 60-second default.
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }

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
}
