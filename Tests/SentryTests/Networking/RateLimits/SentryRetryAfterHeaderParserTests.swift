@testable import Sentry
@_spi(Private) import SentryTestUtils
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
        sut = RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: currentDateProvider)
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
    
    private func testWith(header: String?, expected: Date?) {
        let actual = sut.parse(header)
        XCTAssertEqual(expected, actual)
    }
}
