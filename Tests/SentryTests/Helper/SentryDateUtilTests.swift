import XCTest

class SentryDateUtilTests: XCTestCase {

    private var currentDateProvider: TestCurrentDateProvider!

    override func setUp() {
        super.setUp()
        currentDateProvider = TestCurrentDateProvider()
        CurrentDate.setCurrentDateProvider(currentDateProvider)
        
    }
    
    func testIsInFutureWithFutureDte() {
        XCTAssertTrue(DateUtil.is(inFuture: currentDateProvider.date().addingTimeInterval(1)))
    }
    
    func testIsInFutureWithPresentDate() {
        XCTAssertFalse(DateUtil.is(inFuture: currentDateProvider.date()))
    }
    
    func testIsInFutureWithPastDate() {
           XCTAssertFalse(DateUtil.is(inFuture: currentDateProvider.date().addingTimeInterval(-1)))
       }
    
    func testIsInFutureWithNil() {
        XCTAssertFalse(DateUtil.is(inFuture: nil))
    }

    func testGetMaximumFirstMaximum() {
        let maximum = currentDateProvider.date().addingTimeInterval(1)
        let actual = DateUtil.getMaximumDate(maximum, andOther: currentDateProvider.date())

        XCTAssertEqual(maximum, actual)
    }

    func testGetMaximumSecondMaximum() {
        let maximum = currentDateProvider.date().addingTimeInterval(1)
        let actual = DateUtil.getMaximumDate(currentDateProvider.date(), andOther: maximum)

        XCTAssertEqual(maximum, actual)
    }

    func testGetMaximumWithNil() {
        let date = currentDateProvider.date()
    
        XCTAssertEqual(date, DateUtil.getMaximumDate(nil, andOther: date))
        XCTAssertEqual(date, DateUtil.getMaximumDate(date, andOther: nil))
        XCTAssertNil(DateUtil.getMaximumDate(nil, andOther: nil))
    }

}
