@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryCurrentDateTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
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
