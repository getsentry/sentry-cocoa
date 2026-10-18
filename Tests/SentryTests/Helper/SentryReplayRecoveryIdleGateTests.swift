#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryReplayRecoveryIdleGateTests: XCTestCase {

    func testWaitForIdle_whenNothingPending_shouldReturnImmediately() {
        // -- Arrange --
        let sut = SentryReplayRecoveryIdleGate()

        // -- Act --
        let isIdle = sut.waitForIdle(timeout: 0)

        // -- Assert --
        XCTAssertTrue(isIdle)
    }

    func testWaitForIdle_whenPending_shouldWaitUntilEnd() {
        // -- Arrange --
        let sut = SentryReplayRecoveryIdleGate()
        sut.begin()
        let ended = expectation(description: "Recovery ended")

        // -- Act --
        DispatchQueue.global().async {
            sut.end()
            ended.fulfill()
        }
        let isIdle = sut.waitForIdle(timeout: 1)

        // -- Assert --
        wait(for: [ended], timeout: 1)
        XCTAssertTrue(isIdle)
    }

    func testWaitForIdle_whenTimedOut_shouldReturnFalse() {
        // -- Arrange --
        let sut = SentryReplayRecoveryIdleGate()
        sut.begin()

        // -- Act --
        let isIdle = sut.waitForIdle(timeout: 0)

        // -- Assert --
        XCTAssertFalse(isIdle)
        sut.end()
    }

    func testTryClaim_whenCalledTwice_shouldSucceedOnlyOnce() {
        // -- Arrange --
        let sut = SentryReplayRecoveryIdleGate()

        // -- Act --
        let first = sut.tryClaim()
        let second = sut.tryClaim()

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    func testWaitForIdle_whenBeginHasReturned_shouldNotReportIdleUntilEnd() {
        // -- Arrange --
        let sut = SentryReplayRecoveryIdleGate()
        sut.begin()
        let lock = NSLock()
        var idleResults: [Bool] = []

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            let isIdle = sut.waitForIdle(timeout: 0)
            lock.lock()
            idleResults.append(isIdle)
            lock.unlock()
        }

        // -- Assert --
        XCTAssertFalse(idleResults.contains(true))
        sut.end()
    }

    func testEnd_whenNothingPending_shouldNotLeaveUnbalanced() {
        // -- Arrange --
        let sut = SentryReplayRecoveryIdleGate()

        // -- Act --
        sut.end()

        // -- Assert --
        XCTAssertTrue(sut.waitForIdle(timeout: 0))
    }
}
