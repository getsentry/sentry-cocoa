@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

class ConcurrentRateLimitsDictionaryTests: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: ConcurrentRateLimitsDictionary!
    
    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
        sut = ConcurrentRateLimitsDictionary()
    }
    
    func testTwoRateLimit() {
        let dateA = self.currentDateProvider.date()
        let dateB = dateA.addingTimeInterval(TimeInterval(1))
        sut.addRateLimit(SentryDataCategory.default, validUntil: dateA)
        sut.addRateLimit(SentryDataCategory.error, validUntil: dateB)
        XCTAssertEqual(dateA, self.sut.getRateLimit(for: SentryDataCategory.default))
        XCTAssertEqual(dateB, self.sut.getRateLimit(for: SentryDataCategory.error))
    }
    
    func testOverridingRateLimit() {
        let dateA = self.currentDateProvider.date()
        let dateB = dateA.addingTimeInterval(TimeInterval(1))
        
        sut.addRateLimit(SentryDataCategory.attachment, validUntil: dateA)
        XCTAssertEqual(dateA, self.sut.getRateLimit(for: SentryDataCategory.attachment))

        sut.addRateLimit(SentryDataCategory.attachment, validUntil: dateB)
        XCTAssertEqual(dateB, self.sut.getRateLimit(for: SentryDataCategory.attachment))
    }

    func testConcurrentReadWrite() {
        let queue1 = DispatchQueue(label: "SentryConcurrentRateLimitsStorageTests1", attributes: [.concurrent, .initiallyInactive])
        let queue2 = DispatchQueue(label: "SentryConcurrentRateLimitsStorageTests2", attributes: [.concurrent, .initiallyInactive])

        // SentryDataCategory has 16 cases, so the offsets below use 4/8/12 (with loopCount 4)
        // to keep every fabricated category in range and distinct.
        let loopCount = 4
        let expectation = XCTestExpectation(description: "ConcurrentReadWrite")
        expectation.expectedFulfillmentCount = loopCount * 2
        expectation.assertForOverFulfill = true

        for i in 0..<loopCount {

            let date = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))

            queue1.async {
                let a = self.getCategory(index: i)
                let b = self.getCategory(index: 4 + i)

                self.sut.addRateLimit(a, validUntil: date)
                self.sut.addRateLimit(b, validUntil: date)
                XCTAssertEqual(date, self.sut.getRateLimit(for: a))
                XCTAssertEqual(date, self.sut.getRateLimit(for: b))

                expectation.fulfill()
            }

            queue2.async {
                let c = self.getCategory(index: 8 + i)
                let d = self.getCategory(index: 12 + i)

                self.sut.addRateLimit(c, validUntil: date)

                XCTAssertEqual(date, self.sut.getRateLimit(for: c))
                self.sut.addRateLimit(d, validUntil: date)
                expectation.fulfill()
            }
        }

        queue1.activate()
        queue2.activate()

        wait(for: [expectation], timeout: 10.0)

        for i in 0..<loopCount {
            let date = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))

            XCTAssertEqual(date, sut.getRateLimit(for: getCategory(index: i)))
            XCTAssertEqual(date, sut.getRateLimit(for: getCategory(index: 4 + i)))
            XCTAssertEqual(date, sut.getRateLimit(for: getCategory(index: 8 + i)))
            XCTAssertEqual(date, sut.getRateLimit(for: getCategory(index: 12 + i)))
        }
    }

    private func getCategory(index: Int) -> SentryDataCategory {
        let allCases = SentryDataCategory.allCases
        guard index < allCases.count else {
            XCTFail("Could not create category from index \(index)")
            return SentryDataCategory.default
        }
        return allCases[index]
    }
}
