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

final class AppHangTrackerTests: XCTestCase {

    func testAddObserver_whenDelayExceedsThreshold_shouldNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var notifiedDuration: TimeInterval = 0
        var notifiedOngoing: Bool = false
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            notifiedDuration = duration
            notifiedOngoing = ongoing
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)

        // -- Assert --
        XCTAssertEqual(notifiedDuration, 0.3)
        XCTAssertTrue(notifiedOngoing)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenDelayBelowThreshold_shouldNotNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var notified = false
        let id = sut.addObserver(threshold: 0.25) { _, _ in
            notified = true
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.2, ongoing: true)

        // -- Assert --
        XCTAssertFalse(notified)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenDelayExactlyAtThreshold_shouldNotNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var notified = false
        let id = sut.addObserver(threshold: 0.25) { _, _ in
            notified = true
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.25, ongoing: true)

        // -- Assert --
        XCTAssertFalse(notified)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenMultipleOngoingDelays_shouldNotifyOnlyOnce() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var ongoingCallCount = 0
        let id = sut.addObserver(threshold: 0.25) { _, ongoing in
            if ongoing { ongoingCallCount += 1 }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        // -- Assert --
        XCTAssertEqual(ongoingCallCount, 1)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenHangEndsAfterThresholdCrossed_shouldNotifyWithFinalDuration() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
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

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        XCTAssertEqual(ongoingCalls, 1)
        XCTAssertEqual(endedCalls, 1)
        XCTAssertEqual(endedDuration, 1.0)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenHangEndsWithoutCrossingThreshold_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var notified = false
        let id = sut.addObserver(threshold: 2.0) { _, _ in
            notified = true
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        XCTAssertFalse(notified)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenTwoObserversWithDifferentThresholds_shouldNotifyIndependently() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var lowThresholdNotified = false
        var highThresholdNotified = false
        let id1 = sut.addObserver(threshold: 0.25) { _, ongoing in
            if ongoing { lowThresholdNotified = true }
        }
        let id2 = sut.addObserver(threshold: 2.0) { _, ongoing in
            if ongoing { highThresholdNotified = true }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)

        // -- Assert --
        XCTAssertTrue(lowThresholdNotified)
        XCTAssertFalse(highThresholdNotified)

        // -- Act --
        delayTracker.simulateDelay(duration: 3.0, ongoing: true)

        // -- Assert --
        XCTAssertTrue(highThresholdNotified)

        sut.removeObserver(id: id1)
        sut.removeObserver(id: id2)
    }

    func testAddObserver_whenConsecutiveHangs_shouldResetAndNotifyAgain() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var ongoingCalls = 0
        var endedCalls = 0
        let id = sut.addObserver(threshold: 0.25) { _, ongoing in
            if ongoing {
                ongoingCalls += 1
            } else {
                endedCalls += 1
            }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 0.8, ongoing: false)
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        XCTAssertEqual(ongoingCalls, 2)
        XCTAssertEqual(endedCalls, 2)

        sut.removeObserver(id: id)
    }

    func testRemoveObserver_whenDelayOccurs_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        var notified = false
        let id = sut.addObserver(threshold: 0.25) { _, _ in
            notified = true
        }

        // -- Act --
        sut.removeObserver(id: id)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        // -- Assert --
        XCTAssertFalse(notified)
    }
}
