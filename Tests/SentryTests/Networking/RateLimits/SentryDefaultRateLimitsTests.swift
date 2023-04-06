@testable import Sentry
import XCTest

class SentryDefaultRateLimitsTests: XCTestCase {
    
    private let defaultRetryAfterInSeconds = 60.0

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RateLimits!
    
    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
    
        sut = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), andRateLimitParser: RateLimitParser())
    }
    
    func testNoUpdateCalled() {
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default))
    }
    
    func testRateLimitReached() {
        let category = SentryDataCategory.error
        XCTAssertFalse(sut.isRateLimitActive(category))
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:error:key")
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(category))
        
        // Rate Limit almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(category))
        
        // RateLimit expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(category))
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

        XCTAssertTrue(sut.isRateLimitActive(category))
        // If X-Sentry-Rate-Limits is set Retry-After is ignored
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default))
        
        // Rate Limit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(category))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default))
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

        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default))
    }
    
    func testRetryHeaderIsLikeAllCategories() {
        sut.update(TestResponseFactory.createRateLimitResponse(headerValue: "2::key"))
        sut.update(TestResponseFactory.createRetryAfterResponse(headerValue: "3"))
        
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
        
        // RateLimit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(3))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default))
    }

    func testRetryAfterHeaderDeltaSeconds() {
        assertRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() {
        let headerValue = HttpDateFormatter.string(from: CurrentDate.date().addingTimeInterval(1))
        assertRetryHeaderWith1Second(value: headerValue)
    }
    
    private func assertRetryHeaderWith1Second(value: String) {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: value)
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.attachment))
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.default))
    }
    
    func testRetryAfterHeaderIsEmpty() {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "")
     
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.transaction))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.transaction))
    }
    
    func testLongerRetryHeaderIsKept() {
        let response11 = TestResponseFactory.createRetryAfterResponse(headerValue: "11")
        let response10 = TestResponseFactory.createRetryAfterResponse(headerValue: "10")
        
        sut.update(response11)
        sut.update(response10)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.99))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
        
        let response1 = TestResponseFactory.createRetryAfterResponse(headerValue: "1")
        sut.update(response1)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
    }
    
    func testLongerRateLimitIsKept() {
        let response11 = TestResponseFactory.createRateLimitResponse(headerValue: "11:default;error:key")
        let response10 = TestResponseFactory.createRateLimitResponse(headerValue: "10:default;error:key")
        
        sut.update(response11)
        sut.update(response10)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(10.99))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error))
        
        let response1 = TestResponseFactory.createRateLimitResponse(headerValue: "1:default;error:key")
        sut.update(response1)
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.error))
    }
    
    func testAllCategories() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1::key")
        
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.transaction))
        XCTAssertTrue(sut.isRateLimitActive(SentryDataCategory.default))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.transaction))
        XCTAssertFalse(sut.isRateLimitActive(SentryDataCategory.attachment))
    }
}
