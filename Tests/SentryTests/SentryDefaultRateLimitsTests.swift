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

    func testRetryAfterHeaderDeltaSeconds() {
        testRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() {
        let headerValue = HttpDateFormatter.string(from: CurrentDate.date().addingTimeInterval(1))
        testRetryHeaderWith1Second(value: headerValue)
    }
    
    private func testRetryHeaderWith1Second(value: String) {
        let response = createRetryAfterHeader(headerValue: value)
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
        let response = createRetryAfterHeader(headerValue: "ABC")
        
        assertSetsDefaultRetryAfter(response: response)
    }
    
    func testRetryAfterHeaderIsEmpty() {
        let response = createRetryAfterHeader(headerValue: "")
     
        assertSetsDefaultRetryAfter(response: response)
    }
    
    private func createRetryAfterHeader(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": headerValue])!
    }
    
    private func assertSetsDefaultRetryAfter(response: HTTPURLResponse) {
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitReached(""))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        XCTAssertFalse(sut.isRateLimitReached(""))
    }
}
