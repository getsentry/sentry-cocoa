@testable import Sentry
import SentryTestUtils
import XCTest

class SentryRetryAfterHeaderParserTests: XCTestCase {

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RetryAfterHeaderParser!
    
    private var defaultDate: Date {
        let date = currentDateProvider.date()
        return date.addingTimeInterval(60)
    }
    
    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
        sut = RetryAfterHeaderParser(httpDateParser: HttpDateParser())
    }

    func testNil() {
        testWith(header: nil, expected: nil)
    }
    
    func testFaulty() {
        testWith(header: "ABC", expected: nil)
    }
    
    func testEmpty() {
        testWith(header: "", expected: nil)
    }
    
    func test10Seconds() {
        let date = currentDateProvider.date().addingTimeInterval(10)
        testWith(header: "10", expected: date)
    }
    
    func test10WithComma() {
        let date = currentDateProvider.date().addingTimeInterval(10)
        testWith(header: "10.20", expected: date)
    }
    
    func testHTTPDate() {
        let expected = currentDateProvider.date()
        let httpDateAsString = HttpDateFormatter.string(from: expected)
        testWith(header: httpDateAsString, expected: expected)
    }
    
    func testWith(header: String?, expected: Date?) {
        let actual = sut.parse(header)
        XCTAssertEqual(expected, actual)
    }
}
