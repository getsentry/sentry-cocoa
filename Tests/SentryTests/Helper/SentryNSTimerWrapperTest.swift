import XCTest

class SentryNSTimerWrapperTests: XCTestCase {
    struct Fixture {
        lazy var timerWrapper = SentryNSTimerWrapper()
    }
    lazy var fixture = Fixture()

    func testNonrepeatingTimer() {
        let exp = expectation(description: "timer fires exactly once")
        fixture.timerWrapper.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testRepeatingTimer() {
        var count = 0
        let exp = expectation(description: "timer fires multiple times")
        exp.expectedFulfillmentCount = 2
        fixture.timerWrapper.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
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
