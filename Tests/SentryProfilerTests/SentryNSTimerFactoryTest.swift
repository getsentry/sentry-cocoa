#if !SWIFT_PACKAGE || !SDK_V10
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) import SentryTestUtils
import XCTest

class SentryNSTimerFactoryTests: XCTestCase {
    
    private struct Fixture {
        lazy var timerFactory = SentryNSTimerFactory()
    }
    private lazy var fixture = Fixture()

    func testMockTimer_whenCheckingBeforeNextInterval_shouldNotFireAgain() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let factory = TestSentryNSTimerFactory(currentDateProvider: dateProvider)
        var fireCount = 0
        let timer = factory.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            fireCount += 1
        }
        defer { timer.invalidate() }

        // -- Act --
        dateProvider.advance(by: 60)
        try factory.check()

        // -- Assert --
        XCTAssertEqual(fireCount, 1)

        // -- Act --
        dateProvider.advance(by: 59)
        try factory.check()

        // -- Assert --
        XCTAssertEqual(fireCount, 1)

        // -- Act --
        dateProvider.advance(by: 1)
        try factory.check()

        // -- Assert --
        XCTAssertEqual(fireCount, 2)
    }

    func testNonrepeatingTimer() {
        let exp = expectation(description: "timer fires exactly once")
        fixture.timerFactory.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testRepeatingTimer() {
        var count = 0
        let exp = expectation(description: "timer fires multiple times")
        exp.expectedFulfillmentCount = 2
        fixture.timerFactory.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            guard count < exp.expectedFulfillmentCount else {
                $0.invalidate()
                return
            }
            count += 1
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}
#endif
