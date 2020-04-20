import XCTest
@testable import Sentry

class SentryDefaultRateLimitsTests: XCTestCase {
    
    private let defaultRetryAfterInSeconds = 60.0

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RateLimits!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        
        sut = DefaultRateLimits()
    }
    
    func testNoUpdateCalled() {
        XCTAssertFalse(sut.isRateLimitReached(""))
    }
    
    func testRateLimitReached() {
        let type = "event"
        XCTAssertFalse(sut.isRateLimitReached(type))
        let response = createRateLimitResponse(headerValue: "1:\(type):key")
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitReached(type))
        
        // Rate Limit almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitReached(type))
        
        // RateLimit expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitReached(type))
    }
    
    func testRateLimitExpiredButRetryAfterHeaderNot() {
        let type = "transaction"
        let response = HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: nil,
            headerFields: [
                "Retry-After": "2",
                "X-Sentry-Rate-Limits": "1:\(type):key"
        ])!
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitReached(type))
        
        // Rate Limit expired, but Retry-After not
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(1.999))
        XCTAssertTrue(sut.isRateLimitReached(type))
        XCTAssertTrue(sut.isRateLimitReached("anyType"))
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(2))
        XCTAssertFalse(sut.isRateLimitReached(type))
        XCTAssertFalse(sut.isRateLimitReached("anyType"))
    }

    func testRetryAfterHeaderDeltaSeconds() {
        testRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() {
        let headerValue = HttpDateFormatter.string(from: CurrentDate.date().addingTimeInterval(1))
        testRetryHeaderWith1Second(value: headerValue)
    }
    
    private func testRetryHeaderWith1Second(value: String) {
        let response = createRetryAfterResponse(headerValue: value)
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitReached(""))
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitReached(""))
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitReached(""))
    }
    
    func testFaultyRetryAfterHeader() {
        let response = createRetryAfterResponse(headerValue: "ABC")
        
        assertSetsDefaultRetryAfter(response: response)
    }
    
    func testRetryAfterHeaderIsEmpty() {
        let response = createRetryAfterResponse(headerValue: "")
     
        assertSetsDefaultRetryAfter(response: response)
    }
    
    private func createRetryAfterResponse(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": headerValue])!
    }
    
    private func createRateLimitResponse(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["X-Sentry-Rate-Limits": headerValue])!
    }
    
    private func assertSetsDefaultRetryAfter(response: HTTPURLResponse) {
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitReached(""))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        XCTAssertFalse(sut.isRateLimitReached(""))
    }
}
