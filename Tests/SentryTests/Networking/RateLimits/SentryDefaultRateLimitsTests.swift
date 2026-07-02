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
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testRateLimitReached() {
        let category = SentryDataCategory.error
        XCTAssertFalse(sut.isRateLimitActive(category.rawValue))
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:error:key")
        sut.update(response)
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
        let category = SentryDataCategory.transaction
        if let response = HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "1.1",
            headerFields: [
                "Retry-After": "2",
                "X-Sentry-Rate-Limits": "1:transaction:key"
        ]) {
            sut.update(response)
        }

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
        if let response = HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 503,
            httpVersion: "1.1",
            headerFields: [
                "Retry-After": "2"
        ]) {
            sut.update(response)
        }

        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testRetryHeaderIsLikeAllCategories() {
        sut.update(TestResponseFactory.createRateLimitResponse(headerValue: "2::key"))
        sut.update(TestResponseFactory.createRetryAfterResponse(headerValue: "3"))
        
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        
        // RateLimit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(3))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }

    func testRetryAfterHeaderDeltaSeconds() {
        assertRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() {
        let headerValue = HttpDateFormatter.string(from: currentDateProvider.date().addingTimeInterval(1))
        assertRetryHeaderWith1Second(value: headerValue)
    }
    
    private func assertRetryHeaderWith1Second(value: String) {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: value)
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
    
    func testRetryAfterHeaderIsEmpty() {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "")
     
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
    }
    
    func testLongerRetryHeaderIsKept() {
        let response11 = TestResponseFactory.createRetryAfterResponse(headerValue: "11")
        let response10 = TestResponseFactory.createRetryAfterResponse(headerValue: "10")
        
        sut.update(response11)
        sut.update(response10)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.99))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        
        let response1 = TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        sut.update(response1)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }
    
    func testLongerRateLimitIsKept() {
        let response11 = TestResponseFactory.createRateLimitResponse(headerValue: "11:default;error:key")
        let response10 = TestResponseFactory.createRateLimitResponse(headerValue: "10:default;error:key")
        
        sut.update(response11)
        sut.update(response10)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.99))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        
        let response1 = TestResponseFactory.createRateLimitResponse(headerValue: "1:default;error:key")
        sut.update(response1)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }
    
    func testAllCategories() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1::key")
        
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.transaction.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.attachment.rawValue))
    }
    
    func testMetricBucket() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:::custom")
        
        sut.update(response)
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue), true)
    }
    
    func testMetricBucket_NoNamespace() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket::")
        
        sut.update(response)
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue), true)
    }
    
    func testMetricBucket_EmptyNamespace() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:::")
        
        sut.update(response)
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue), true)
    }
    
    func testMetricBucket_NamespaceExclusivelyThanOtherCustom() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:organization:quota_exceeded:customs;cust")
        
        sut.update(response)
        XCTAssertFalse(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue))
    }
    
    func testMetricBucket_EmptyNamespaces() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:metric_bucket:::;")
        
        sut.update(response)
        XCTAssertFalse(self.sut.isRateLimitActive(SentryDataCategory.metricBucket.rawValue))
    }
    
    func testIgnoreNamespaceForNonMetricBucket() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:error:::customs;cust")

        sut.update(response)
        XCTAssertEqual(self.sut.isRateLimitActive(SentryDataCategory.error.rawValue), true)
    }

    /// Reproduces https://github.com/getsentry/sentry-cocoa/issues/8322
    ///
    /// Relay sends the rate-limit header with a lowercase field name over HTTP/2
    /// (e.g. `x-sentry-rate-limits`). `HTTPURLResponse.allHeaderFields` preserves that
    /// casing, so a case-sensitive lookup for `X-Sentry-Rate-Limits` misses the header,
    /// the SDK falls through to the generic 429 handling and rate-limits *all* categories
    /// instead of only the one the server limited.
    func testUpdate_whenRateLimitHeaderHasLowercaseKey_shouldOnlyRateLimitGivenCategory() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: [
                "x-sentry-rate-limits": "60:replay:organization:replay_usage_exceeded"
            ]))

        // -- Act --
        sut.update(response)

        // -- Assert --
        // The server only limited replay, so only replay must be rate limited.
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))

        // All other categories, including user feedback, must still be sent.
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.feedback.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.session.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.attachment.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }

    /// Companion to the reproduction above: over HTTP/1 the header arrives in relay's canonical
    /// casing (`X-Sentry-Rate-Limits`). This must keep scoping the limit to the given category.
    func testUpdate_whenRateLimitHeaderHasCanonicalKey_shouldOnlyRateLimitGivenCategory() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "1.1",
            headerFields: [
                "X-Sentry-Rate-Limits": "60:replay:organization:replay_usage_exceeded"
            ]))

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.feedback.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }

    /// A bare 429 without a rate-limit header must still back off *all* categories. This guards
    /// that the fix for #8322 did not weaken the intended generic-429 behavior.
    func testUpdate_when429WithoutRateLimitHeader_shouldRateLimitAllCategories() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["Retry-After": "1"]))

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.replay.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.feedback.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default.rawValue))
    }

    /// The `Retry-After` header must also be read case-insensitively, since over HTTP/2 it arrives
    /// lowercased as `retry-after`.
    func testUpdate_whenRetryAfterHeaderHasLowercaseKey_shouldRateLimitAllCategories() throws {
        // -- Arrange --
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["retry-after": "1"]))

        // -- Act --
        sut.update(response)

        // -- Assert --
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
        // The 1-second Retry-After must have been parsed, not the 60-second default.
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.error.rawValue))
    }

    // MARK: - Case-sensitive header fallback (used below macOS 10.15)

    /// The fallback branch of `sentryHeaderValue(forName:)` only runs on macOS < 10.15, which our
    /// tests never run on, so we test the extracted lookup directly to be sure it works.
    func testCaseSensitiveHeaderValueFallback_whenLowercaseKey_returnsValue() throws {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["x-sentry-rate-limits": "60:replay:organization:replay_usage_exceeded"]))

        XCTAssertEqual(
            response.sentryCaseSensitiveHeaderValue(forName: "X-Sentry-Rate-Limits"),
            "60:replay:organization:replay_usage_exceeded")
    }

    func testCaseSensitiveHeaderValueFallback_whenCanonicalKey_returnsValue() throws {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "1.1",
            headerFields: ["X-Sentry-Rate-Limits": "60:replay:organization:replay_usage_exceeded"]))

        XCTAssertEqual(
            response.sentryCaseSensitiveHeaderValue(forName: "X-Sentry-Rate-Limits"),
            "60:replay:organization:replay_usage_exceeded")
    }

    func testCaseSensitiveHeaderValueFallback_whenHeaderMissing_returnsNil() throws {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "2.0",
            headerFields: ["some-other-header": "value"]))

        XCTAssertNil(response.sentryCaseSensitiveHeaderValue(forName: "X-Sentry-Rate-Limits"))
    }
}
