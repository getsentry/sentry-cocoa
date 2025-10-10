@_spi(Private) import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryDateUtilTests: XCTestCase {

    private var currentDateProvider: TestCurrentDateProvider!

    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
    }
    
    func testIsInFutureWithFutureDte() {
        let sut = SentryDateUtil(currentDateProvider: currentDateProvider)
        XCTAssertTrue(sut.isInFuture(currentDateProvider.date().addingTimeInterval(1)))
    }
    
    func testIsInFutureWithPresentDate() {
        let sut = SentryDateUtil(currentDateProvider: currentDateProvider)
        
        XCTAssertFalse(sut.isInFuture(currentDateProvider.date()))
    }
    
    func testIsInFutureWithPastDate() {
        let sut = SentryDateUtil(currentDateProvider: currentDateProvider)
        
        XCTAssertFalse(sut.isInFuture(currentDateProvider.date().addingTimeInterval(-1)))
   }
    
    func testIsInFutureWithNil() {
        let sut = SentryDateUtil(currentDateProvider: currentDateProvider)
        
        XCTAssertFalse(sut.isInFuture(nil))
    }

    func testGetMaximumFirstMaximum() {
        let maximum = currentDateProvider.date().addingTimeInterval(1)
        let actual = SentryDateUtil.getMaximumDate(maximum, andOther: currentDateProvider.date())

        XCTAssertEqual(maximum, actual)
    }

    func testGetMaximumSecondMaximum() {
        let maximum = currentDateProvider.date().addingTimeInterval(1)
        let actual = SentryDateUtil.getMaximumDate(currentDateProvider.date(), andOther: maximum)

        XCTAssertEqual(maximum, actual)
    }

    func testGetMaximumWithNil() {
        let date = currentDateProvider.date()
    
        XCTAssertEqual(date, SentryDateUtil.getMaximumDate(nil, andOther: date))
        XCTAssertEqual(date, SentryDateUtil.getMaximumDate(date, andOther: nil))
        XCTAssertNil(SentryDateUtil.getMaximumDate(nil, andOther: nil))
    }

    func testJavascriptDate() {
        let testDate = Date(timeIntervalSince1970: 60)
        let timestamp = SentryDateUtil.millisecondsSince1970(testDate)
        
        XCTAssertEqual(timestamp, 60_000)
    }
    
}
