@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

private struct HangCallback {
    let duration: TimeInterval
    let ongoing: Bool
}

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
        let callbacks = Invocations<HangCallback>()
        let expectation = expectation(description: "Observer notified")
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
            expectation.fulfill()
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)

        // -- Assert --
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertEqual(callbacks.first?.duration, 0.3)
        XCTAssertEqual(callbacks.first?.ongoing, true)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenDelayBelowThreshold_shouldNotNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.2, ongoing: true)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenDelayExactlyAtThreshold_shouldNotNotifyObserver() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.25, ongoing: true)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenMultipleOngoingDelays_shouldNotifyOnlyOnce() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let expectation = expectation(description: "Observer notified")
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
            expectation.fulfill()
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        // -- Assert --
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertEqual(callbacks.first?.ongoing, true)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenHangEndsAfterThresholdCrossed_shouldNotifyWithFinalDuration() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let ongoingExpectation = expectation(description: "Ongoing notified")
        let endedExpectation = expectation(description: "Ended notified")
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
            if ongoing {
                ongoingExpectation.fulfill()
            } else {
                endedExpectation.fulfill()
            }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        wait(for: [ongoingExpectation, endedExpectation], timeout: 1)
        XCTAssertEqual(callbacks.count, 2)
        XCTAssertEqual(callbacks.get(0)?.ongoing, true)
        XCTAssertEqual(callbacks.get(1)?.ongoing, false)
        XCTAssertEqual(callbacks.get(1)?.duration, 1.0)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenHangEndsWithoutCrossingThreshold_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let id = sut.addObserver(threshold: 2.0) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)

        sut.removeObserver(id: id)
    }

    func testAddObserver_whenTwoObserversWithDifferentThresholds_shouldNotifyIndependently() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let lowCallbacks = Invocations<HangCallback>()
        let highCallbacks = Invocations<HangCallback>()
        let lowExpectation = expectation(description: "Low threshold notified")
        let id1 = sut.addObserver(threshold: 0.25) { duration, ongoing in
            lowCallbacks.record(HangCallback(duration: duration, ongoing: ongoing))
            lowExpectation.fulfill()
        }
        let id2 = sut.addObserver(threshold: 2.0) { duration, ongoing in
            highCallbacks.record(HangCallback(duration: duration, ongoing: ongoing))
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)

        // -- Assert --
        wait(for: [lowExpectation], timeout: 1)
        XCTAssertEqual(lowCallbacks.count, 1)
        XCTAssertTrue(highCallbacks.isEmpty)

        // -- Act --
        let highExpectation = expectation(description: "High threshold notified")
        sut.removeObserver(id: id2)
        let id3 = sut.addObserver(threshold: 2.0) { duration, ongoing in
            highCallbacks.record(HangCallback(duration: duration, ongoing: ongoing))
            highExpectation.fulfill()
        }
        delayTracker.simulateDelay(duration: 3.0, ongoing: true)

        // -- Assert --
        wait(for: [highExpectation], timeout: 1)
        XCTAssertEqual(highCallbacks.count, 1)

        sut.removeObserver(id: id1)
        sut.removeObserver(id: id3)
    }

    func testAddObserver_whenConsecutiveHangs_shouldResetAndNotifyAgain() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let firstOngoing = expectation(description: "First ongoing")
        let firstEnded = expectation(description: "First ended")
        let secondOngoing = expectation(description: "Second ongoing")
        let secondEnded = expectation(description: "Second ended")
        var ongoingCount = 0
        var endedCount = 0
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
            if ongoing {
                ongoingCount += 1
                if ongoingCount == 1 { firstOngoing.fulfill() }
                if ongoingCount == 2 { secondOngoing.fulfill() }
            } else {
                endedCount += 1
                if endedCount == 1 { firstEnded.fulfill() }
                if endedCount == 2 { secondEnded.fulfill() }
            }
        }

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

        sut.removeObserver(id: id)
    }

    func testRemoveObserver_whenDelayOccurs_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockRunLoopDelayTracker()
        let sut = DefaultAppHangTracker(runLoopDelayTracker: delayTracker)
        let callbacks = Invocations<HangCallback>()
        let id = sut.addObserver(threshold: 0.25) { duration, ongoing in
            callbacks.record(HangCallback(duration: duration, ongoing: ongoing))
        }

        // -- Act --
        sut.removeObserver(id: id)
        delayTracker.simulateDelay(duration: 1.0, ongoing: true)

        // -- Assert --
        XCTAssertTrue(callbacks.isEmpty)
    }
}
