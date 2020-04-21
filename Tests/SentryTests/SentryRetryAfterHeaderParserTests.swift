import XCTest
@testable import Sentry

class SentryRetryAfterHeaderParserTests: XCTestCase {

    private var currentDateProvider: TestCurrentDateProvider!
    private var sut: RetryAfterHeaderParser!
    
    private var defaultDate: Date {
        get {
            let date = currentDateProvider.date()
            return date.addingTimeInterval(60)
        }
    }
    
    override func setUp() {
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        sut = RetryAfterHeaderParser(httpDateParser: HttpDateParser())
    }

    func testNil()  {
        testWith(header: nil, expected: defaultDate)
    }
    
    func testFaulty() {
        testWith(header: "ABC", expected: defaultDate)
    }
    
    func testEmpty() {
        testWith(header: "", expected: defaultDate)
    }
    
    func test10Seconds() {
        let date = currentDateProvider.date().addingTimeInterval(10)
        testWith(header: "10", expected: date)
    }
    
    func testHTTPDate() {
        let expected = currentDateProvider.date()
        let httpDateAsString = HttpDateFormatter.string(from: expected)
        testWith(header: httpDateAsString, expected: expected)
    }
    
    func testWith(header: String?, expected: Date) {
        let actual = sut.parse(header)
        XCTAssertEqual(expected, actual)
    }
}
