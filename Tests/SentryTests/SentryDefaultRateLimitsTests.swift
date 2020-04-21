import XCTest
@testable import Sentry

class SentryDefaultRateLimitsTests: XCTestCase {
    
    private let defaultRetryAfterInSeconds = 60.0

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RateLimits!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
    
        sut = DefaultRateLimits(parsers: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), rateLimitParser: RateLimitParser())
    }
    
    func testNoUpdateCalled() {
        XCTAssertFalse(sut.isRateLimitActive(""))
    }
    
    func testRateLimitReached() {
        let type = "event"
        XCTAssertFalse(sut.isRateLimitActive(type))
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(type):key")
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(type))
        
        // Rate Limit almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(type))
        
        // RateLimit expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(type))
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
        XCTAssertTrue(sut.isRateLimitActive(type))
        
        // Rate Limit expired, but Retry-After not
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(1.999))
        XCTAssertTrue(sut.isRateLimitActive(type))
        XCTAssertTrue(sut.isRateLimitActive("anyType"))
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(2))
        XCTAssertFalse(sut.isRateLimitActive(type))
        XCTAssertFalse(sut.isRateLimitActive("anyType"))
    }

    func testRetryAfterHeaderDeltaSeconds() {
        testRetryHeaderWith1Second(value: "1")
    }
    
    func testRetryAfterHeaderHttpDate() {
        let headerValue = HttpDateFormatter.string(from: CurrentDate.date().addingTimeInterval(1))
        testRetryHeaderWith1Second(value: headerValue)
    }
    
    private func testRetryHeaderWith1Second(value: String) {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: value)
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(""))
        
        // Retry-After almost expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(0.999))
        XCTAssertTrue(sut.isRateLimitActive(""))
        
        // Retry-After expired
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(""))
    }
    
    func testRetryAfterHeaderIsEmpty() {
        let response = TestResponseFactory.createRetryAfterResponse(headerValue: "")
     
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(""))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(defaultRetryAfterInSeconds))
        XCTAssertFalse(sut.isRateLimitActive(""))
    }
    
    func testMultipleConcurrentUpdates() {
        let queue1 = DispatchQueue(label: "SentryDefaultRateLimitsTests1", qos: .utility, attributes: [.concurrent, .initiallyInactive])
        let queue2 = DispatchQueue(label: "SentryDefaultRateLimitsTests2", qos: .utility, attributes: [.concurrent, .initiallyInactive])
        
        let group = DispatchGroup()
        for i in Array(0...1000) {
            startWorkItemTest(i: i, queue: queue1, group: group)
        }
        for i in Array(1001...2000) {
            startWorkItemTest(i: i, queue: queue2, group: group)
        }
        
        queue1.activate()
        queue2.activate()
        group.wait()
        
        // Make sure that all 2000 are saved and none are overwritten by
        // race conditions.
        for i in Array(0...2000) {
            XCTAssertTrue(self.sut.isRateLimitActive(String(i)))
        }
    }
    
    func startWorkItemTest(i: Int, queue: DispatchQueue, group: DispatchGroup) {
        group.enter()
        queue.async {
            let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(i):key")
            self.sut.update(response)
            XCTAssertTrue(self.sut.isRateLimitActive(String(i)))
            group.leave()
        }
    }
}
