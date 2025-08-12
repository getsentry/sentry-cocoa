@testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryHttpDateParserTests: XCTestCase {
    
    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: HttpDateParser!

    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
        sut = HttpDateParser()
    }

    func testDefaultDate() {
        let expected = currentDateProvider.date()
        let httpDateAsString = HttpDateFormatter.string(from: expected)
        let actual = sut.date(from: httpDateAsString)
        
        XCTAssertEqual(expected, actual)
    }

    func testWithMultipleWorkItemsInParallel() {
        let queue1 = DispatchQueue(label: "SentryHttpDateParserTests1", attributes: [.concurrent, .initiallyInactive])
        let queue2 = DispatchQueue(label: "SentryHttpDateParserTests2", attributes: [.concurrent, .initiallyInactive])
        
        let loopCount = 1_000
        let expectation = XCTestExpectation(description: "WithMultipleWorkItemsInParallel")
        expectation.expectedFulfillmentCount = loopCount * 2
        expectation.assertForOverFulfill = true

        for i in 0..<loopCount {
            queue1.async {
                let expected = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))
                let httpDateAsString = HttpDateFormatter.string(from: expected)
                let actual = self.sut.date(from: httpDateAsString)
                
                XCTAssertEqual(expected, actual)
                expectation.fulfill()
            }
            queue2.async {
                let expected = self.currentDateProvider.date().addingTimeInterval(TimeInterval(i))
                let httpDateAsString = HttpDateFormatter.string(from: expected)
                let actual = self.sut.date(from: httpDateAsString)
                
                XCTAssertEqual(expected, actual)
                expectation.fulfill()
            }
        }
        
        queue1.activate()
        queue2.activate()

        wait(for: [expectation], timeout: 10.0)
    }
}
