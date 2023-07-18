@testable import Sentry
import SentryTestUtils
import XCTest

class SentryCurrentDateTests: XCTestCase {

    func testSetNoCurrentDateProvider() {
        let firstDate = Date()
        let secondDate = SentryDependencyContainer.sharedInstance().dateProvider.date()
        let thirdDate = Date()

        XCTAssertGreaterThanOrEqual(secondDate, firstDate)
        XCTAssertGreaterThanOrEqual(thirdDate, secondDate)
    }

    func testDefaultCurrentDateProvider() {
        let firstDate = Date()
        let secondDate = SentryDependencyContainer.sharedInstance().dateProvider.date()
        let thirdDate = Date()

        XCTAssertGreaterThanOrEqual(secondDate, firstDate)
        XCTAssertGreaterThanOrEqual(thirdDate, secondDate)
    }

    func testTestCurrentDateProvider() {
        SentryDependencyContainer.sharedInstance().dateProvider = TestCurrentDateProvider()
        let expected = Date(timeIntervalSinceReferenceDate: 0)

        let actual = SentryDependencyContainer.sharedInstance().dateProvider.date()

        XCTAssertEqual(expected, actual)
    }
}
