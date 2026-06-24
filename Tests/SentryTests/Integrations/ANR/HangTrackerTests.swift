@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

private class MockRunLoopDelayTracker: RunLoopDelayTracker {
    private var observers: [UUID: (TimeInterval, Bool) -> Void] = [:]

    func addObserver(handler: @escaping (TimeInterval, Bool) -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        return id
    }

    func removeObserver(id: UUID) {
        observers.removeValue(forKey: id)
    }

    func simulateDelay(duration: TimeInterval, ongoing: Bool) {
        for observer in observers.values {
            observer(duration, ongoing)
        }
    }
}

final class HangTrackerTests: XCTestCase {

    func testObserverNotifiedWhenThresholdExceeded() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var notifiedDuration: TimeInterval = 0
        var notifiedOngoing: Bool = false
        let expectation = XCTestExpectation()

        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            notifiedDuration = duration
            notifiedOngoing = ongoing
            expectation.fulfill()
        }

        delayTracker.simulateDelay(duration: 0.3, ongoing: true)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(notifiedDuration, 0.3)
        XCTAssertTrue(notifiedOngoing)

        sut.removeObserver(id: id)
    }

    func testObserverNotNotifiedWhenBelowThreshold() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var notified = false
        let id = sut.addObserver(threshold: 0.25) { _, _ in
            notified = true
        }

        delayTracker.simulateDelay(duration: 0.2, ongoing: true)

        XCTAssertFalse(notified)

        sut.removeObserver(id: id)
    }

    func testObserverNotNotifiedWhenExactlyAtThreshold() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var notified = false
        let id = sut.addObserver(threshold: 0.25) { _, _ in
            notified = true
        }

        delayTracker.simulateDelay(duration: 0.25, ongoing: true)

        XCTAssertFalse(notified)

        sut.removeObserver(id: id)
    }

    func testObserverOnlyNotifiedOncePerHang() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var callCount = 0
        let id = sut.addObserver(threshold: 0.25) { _, ongoing in
            if ongoing { callCount += 1 }
        }

        delayTracker.simulateDelay(duration: 0.3, ongoing: true)
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        XCTAssertEqual(callCount, 1, "Observer should only be notified once per hang")

        sut.removeObserver(id: id)
    }

    func testObserverReceivesEndNotificationAfterThresholdCrossed() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var ongoingCalls = 0
        var endedCalls = 0
        var endedDuration: TimeInterval = 0
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            if ongoing {
                ongoingCalls += 1
            } else {
                endedCalls += 1
                endedDuration = duration
            }
        }

        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        XCTAssertEqual(ongoingCalls, 1)
        XCTAssertEqual(endedCalls, 1)
        XCTAssertEqual(endedDuration, 1.0)

        sut.removeObserver(id: id)
    }

    func testObserverDoesNotReceiveEndNotificationWithoutPriorOngoing() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var notified = false
        let id = sut.addObserver(threshold: 2.0) { _, _ in
            notified = true
        }

        // Delay below threshold, then ended — observer should not get the end notification
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        XCTAssertFalse(notified)

        sut.removeObserver(id: id)
    }

    func testMultipleObserversWithDifferentThresholds() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var lowThresholdNotified = false
        var highThresholdNotified = false

        let id1 = sut.addObserver(threshold: 0.25) { _, ongoing in
            if ongoing { lowThresholdNotified = true }
        }
        let id2 = sut.addObserver(threshold: 2.0) { _, ongoing in
            if ongoing { highThresholdNotified = true }
        }

        // Duration exceeds only the low threshold
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)

        XCTAssertTrue(lowThresholdNotified, "Low threshold observer should be notified")
        XCTAssertFalse(highThresholdNotified, "High threshold observer should NOT be notified")

        // Duration now exceeds both thresholds
        delayTracker.simulateDelay(duration: 3.0, ongoing: true)

        XCTAssertTrue(highThresholdNotified, "High threshold observer should now be notified")

        sut.removeObserver(id: id1)
        sut.removeObserver(id: id2)
    }

    func testConsecutiveHangsResetState() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var ongoingCalls = 0
        var endedCalls = 0
        let id = sut.addObserver(threshold: 0.25) { _, ongoing in
            if ongoing {
                ongoingCalls += 1
            } else {
                endedCalls += 1
            }
        }

        // First hang
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 0.8, ongoing: false)

        XCTAssertEqual(ongoingCalls, 1)
        XCTAssertEqual(endedCalls, 1)

        // Second hang — should be detected again
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        XCTAssertEqual(ongoingCalls, 2, "Second hang should trigger a new ongoing notification")
        XCTAssertEqual(endedCalls, 2, "Second hang should trigger a new ended notification")

        sut.removeObserver(id: id)
    }

    func testRemoveObserverStopsNotifications() {
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultHangTracker(runLoopDelayTracker: delayTracker)

        var notified = false
        let id = sut.addObserver(threshold: 0.25) { _, _ in
            notified = true
        }

        sut.removeObserver(id: id)

        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        XCTAssertFalse(notified)
    }
}
