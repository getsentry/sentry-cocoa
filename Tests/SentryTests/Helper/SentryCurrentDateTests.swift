@testable import Sentry
import XCTest

class SentryCurrentDateTests: XCTestCase {

    func testSetNoCurrentDateProvider() {
        let firstDate = Date()
        let secondDate = CurrentDate.date()
        let thirdDate = Date()

        XCTAssertGreaterThanOrEqual(secondDate, firstDate)
        XCTAssertGreaterThanOrEqual(thirdDate, secondDate)
    }

    func testDefaultCurrentDateProvider() {
        CurrentDate.setCurrentDateProvider(DefaultCurrentDateProvider())
        let firstDate = Date()
        let secondDate = CurrentDate.date()
        let thirdDate = Date()

        XCTAssertGreaterThanOrEqual(secondDate, firstDate)
        XCTAssertGreaterThanOrEqual(thirdDate, secondDate)
    }

    func testTestCurrentDateProvider() {
        CurrentDate.setCurrentDateProvider(TestCurrentDateProvider())
        let expected = Date(timeIntervalSinceReferenceDate: 0)

        let actual = CurrentDate.date()

        XCTAssertEqual(expected, actual)
    }
}
