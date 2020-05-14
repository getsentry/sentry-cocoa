import XCTest
@testable import Sentry

class SentryCurrentDateTests: XCTestCase {

    func testSetNoCurrentDateProvider() {
        let firstDate = Date.init()
        let secondDate = CurrentDate.date()
        let thirdDate = Date.init()

        XCTAssertGreaterThanOrEqual(secondDate, firstDate)
        XCTAssertGreaterThanOrEqual(thirdDate, secondDate)
    }

    func testDefaultCurrentDateProvider() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider())
        let firstDate = Date.init()
        let secondDate = CurrentDate.date()
        let thirdDate = Date.init()

        XCTAssertGreaterThanOrEqual(secondDate, firstDate)
        XCTAssertGreaterThanOrEqual(thirdDate, secondDate)
    }

    func testTestCurrentDateProvider() {
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
        let expected = Date.init(timeIntervalSinceReferenceDate: 0)

        let actual = CurrentDate.date()

        XCTAssertEqual(expected, actual)
    }
}
