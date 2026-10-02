@_spi(Private) @testable import Sentry
import XCTest

class SentryStartupCrashFlushTests: XCTestCase {

    func testRecoveryWaitTimeout_shouldReserveMinimumFlushDuration() {
        // -- Arrange --
        let expected = SentryStartupCrashFlush.duration - SentryStartupCrashFlush.minimumFlushDuration

        // -- Act --
        let timeout = SentryStartupCrashFlush.recoveryWaitTimeout

        // -- Assert --
        XCTAssertEqual(timeout, expected)
        XCTAssertEqual(timeout, 4, accuracy: 0.001)
    }

    func testFlushTimeout_whenRecoveryWaitedNothing_shouldUseFullBudget() {
        // -- Arrange --
        let elapsed: TimeInterval = 0

        // -- Act --
        let timeout = SentryStartupCrashFlush.flushTimeout(afterWaiting: elapsed)

        // -- Assert --
        XCTAssertEqual(timeout, SentryStartupCrashFlush.duration, accuracy: 0.001)
    }

    func testFlushTimeout_whenRecoveryUsedPartOfBudget_shouldFlushRemainder() {
        // -- Arrange --
        let elapsed: TimeInterval = 2

        // -- Act --
        let timeout = SentryStartupCrashFlush.flushTimeout(afterWaiting: elapsed)

        // -- Assert --
        XCTAssertEqual(timeout, 3, accuracy: 0.001)
    }

    func testFlushTimeout_whenRecoveryUsedFullWait_shouldKeepMinimumFlush() {
        // -- Arrange --
        let elapsed = SentryStartupCrashFlush.recoveryWaitTimeout

        // -- Act --
        let timeout = SentryStartupCrashFlush.flushTimeout(afterWaiting: elapsed)

        // -- Assert --
        XCTAssertEqual(timeout, SentryStartupCrashFlush.minimumFlushDuration, accuracy: 0.001)
    }

    func testFlushTimeout_whenRecoveryExceededBudget_shouldKeepMinimumFlush() {
        // -- Arrange --
        let elapsed: TimeInterval = 10

        // -- Act --
        let timeout = SentryStartupCrashFlush.flushTimeout(afterWaiting: elapsed)

        // -- Assert --
        XCTAssertEqual(timeout, SentryStartupCrashFlush.minimumFlushDuration, accuracy: 0.001)
    }
}
