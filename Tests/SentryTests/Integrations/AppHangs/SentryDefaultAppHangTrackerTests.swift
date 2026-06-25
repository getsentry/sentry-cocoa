@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDefaultAppHangTrackerTests: XCTestCase {

    func testAddObserver_whenDelayExceedsThreshold_shouldNotifyObserver() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let expectation = expectation(description: "Observer notified")
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            expectation.fulfill()
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)

        // -- Assert --
        wait(for: [expectation], timeout: 1)

        let hang = try XCTUnwrap(callbacks.first)
        XCTAssertEqual(hang.duration, 0.3)
        XCTAssertEqual(hang.state, .started)

        // Assert no additional invocations
        XCTAssertEqual(callbacks.count, 1)
    }

    func testAddObserver_whenDelayBelowThreshold_shouldNotNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.2, ongoing: true)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)
    }

    func testAddObserver_whenDelayExactlyAtThreshold_shouldNotNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.25, ongoing: true)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)
    }

    func testAddObserver_whenMultipleOngoingDelays_shouldNotifyOnlyOnce() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let expectation = expectation(description: "Observer notified")
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            expectation.fulfill()
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        // -- Assert --
        wait(for: [expectation], timeout: 1)

        let hang = try XCTUnwrap(callbacks.first)
        XCTAssertEqual(hang.state, .started)

        // Assert no additional invocations
        XCTAssertEqual(callbacks.count, 1)
    }

    func testAddObserver_whenHangEndsAfterThresholdCrossed_shouldNotifyWithFinalDuration() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let ongoingExpectation = expectation(description: "Ongoing notified")
        let endedExpectation = expectation(description: "Ended notified")
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            switch hang.state {
            case .started:
                ongoingExpectation.fulfill()
            case .ended:
                endedExpectation.fulfill()
            }
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        wait(for: [ongoingExpectation, endedExpectation], timeout: 1)

        let beginInvocation = try XCTUnwrap(callbacks.get(0))
        XCTAssertEqual(beginInvocation.state, .started)

        let endInvocation = try XCTUnwrap(callbacks.get(1))
        XCTAssertEqual(endInvocation.state, .ended)
        XCTAssertEqual(endInvocation.duration, 1.0)

        // Assert no additional invocations
        XCTAssertEqual(callbacks.count, 2)
    }

    func testAddObserver_whenHangEndsWithoutCrossingThreshold_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let token = sut.addObserver(threshold: 2.0) { hang in
            callbacks.record(hang)
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)
    }

    func testAddObserver_whenTwoObserversWithDifferentThresholds_shouldNotifyIndependently() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let lowCallbacks = Invocations<SentryAppHang>()
        let highCallbacks = Invocations<SentryAppHang>()
        let lowExpectation = expectation(description: "Low threshold notified")
        let token1 = sut.addObserver(threshold: 0.25) { hang in
            lowCallbacks.record(hang)
            lowExpectation.fulfill()
        }
        let token2 = sut.addObserver(threshold: 2.0) { hang in
            highCallbacks.record(hang)
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)

        // -- Assert --
        wait(for: [lowExpectation], timeout: 1)
        XCTAssertEqual(lowCallbacks.count, 1)
        XCTAssertTrue(highCallbacks.isEmpty)

        // -- Act --
        let highExpectation = expectation(description: "High threshold notified")
        sut.removeObserver(token: token2)
        let token3 = sut.addObserver(threshold: 2.0) { hang in
            highCallbacks.record(hang)
            highExpectation.fulfill()
        }
        defer { sut.removeObserver(token: token3) }
        delayTracker.simulateDelay(duration: 3.0, ongoing: true)

        // -- Assert --
        wait(for: [highExpectation], timeout: 1)
        XCTAssertEqual(highCallbacks.count, 1)

        sut.removeObserver(token: token1)
        sut.removeObserver(token: token3)
    }

    func testAddObserver_whenConsecutiveHangs_shouldResetAndNotifyAgain() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let firstOngoing = expectation(description: "First ongoing")
        let firstEnded = expectation(description: "First ended")
        let secondOngoing = expectation(description: "Second ongoing")
        let secondEnded = expectation(description: "Second ended")
        var ongoingCount = 0
        var endedCount = 0
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            switch hang.state {
            case .started:
                ongoingCount += 1
                if ongoingCount == 1 { firstOngoing.fulfill() }
                if ongoingCount == 2 { secondOngoing.fulfill() }
            case .ended:
                endedCount += 1
                if endedCount == 1 { firstEnded.fulfill() }
                if endedCount == 2 { secondEnded.fulfill() }
            }
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 0.8, ongoing: false)

        // -- Assert --
        wait(for: [firstOngoing, firstEnded], timeout: 1)
        XCTAssertEqual(callbacks.count, 2)

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        wait(for: [secondOngoing, secondEnded], timeout: 1)
        XCTAssertEqual(callbacks.count, 4)
    }

    func testRemoveObserver_whenDelayOccurs_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
        }

        // -- Act --
        sut.removeObserver(token: token)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)
    }
}

private class MockSentryRunLoopDelayTracker: SentryRunLoopDelayTracker {
    private var observers = [SentryRunLoopDelayTrackerObserverToken: SentryRunLoopDelayTrackerHandler]()

    func addObserver(handler: @escaping SentryRunLoopDelayTrackerHandler) -> SentryRunLoopDelayTrackerObserverToken {
        let token = SentryRunLoopDelayTrackerObserverToken()
        observers[token] = handler
        return token
    }

    func removeObserver(token: SentryRunLoopDelayTrackerObserverToken) {
        observers.removeValue(forKey: token)
    }

    func simulateDelay(duration: TimeInterval, ongoing: Bool) {
        for observer in observers.values {
            observer(.init(duration: duration, isOngoing: ongoing))
        }
    }
}
