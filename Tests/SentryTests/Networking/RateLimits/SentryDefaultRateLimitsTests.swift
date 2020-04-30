import XCTest
@testable import Sentry

class SentryDefaultRateLimitsTests: XCTestCase {
    
    private let defaultRetryAfterInSeconds = 60.0

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RateLimits!
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
    
        sut = DefaultRateLimits(retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser()), andRateLimitParser: RateLimitParser())
    }
    
    func testNoUpdateCalled() {
        XCTAssertFalse(sut.isRateLimitActive(""))
    }
    
    func testRateLimitReached() {
        let category = "event"
        XCTAssertFalse(sut.isRateLimitActive(category))
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1:\(category):key")
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
        let category = "transaction"
        let response = HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "1.1",
            headerFields: [
                "Retry-After": "2",
                "X-Sentry-Rate-Limits": "1:\(category):key"
        ])!
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(category))
        // If X-Sentry-Rate-Limits is set Retry-After is ignored
        XCTAssertFalse(sut.isRateLimitActive("anyCategory"))
        
        // Rate Limit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(category))
        XCTAssertFalse(sut.isRateLimitActive("anyCategory"))
    }
    
    func testRetryHeaderIn503() {
        let response = HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 503,
            httpVersion: "1.1",
            headerFields: [
                "Retry-After": "2"
        ])!
        sut.update(response)

        XCTAssertFalse(sut.isRateLimitActive("anyCategory"))
    }
    
    func testRetryHeaderIsLikeAllCategories() {
        sut.update(TestResponseFactory.createRateLimitResponse(headerValue: "2::key"))
        sut.update(TestResponseFactory.createRetryAfterResponse(headerValue: "1"))
        
        XCTAssertTrue(sut.isRateLimitActive("any"))
        
        // RateLimit expired
        let date = currentDateProvider.date()
        currentDateProvider.setDate(date: date.addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive("any"))
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
    
    func testAllCategories() {
        let response = TestResponseFactory.createRateLimitResponse(headerValue: "1::key")
        
        sut.update(response)
        XCTAssertTrue(sut.isRateLimitActive(""))
        XCTAssertTrue(sut.isRateLimitActive("SomeCategory"))
        
        currentDateProvider.setDate(date: currentDateProvider.date().addingTimeInterval(1))
        XCTAssertFalse(sut.isRateLimitActive(""))
        XCTAssertFalse(sut.isRateLimitActive("SomeCategory"))
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
