@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDefaultAppHangTrackerTests: XCTestCase {

    func testAddObserver_whenDelayExceedsThreshold_shouldNotifyObserver() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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
        XCTAssertEqual(hang.duration, 0.3)

        // Assert no additional invocations
        XCTAssertEqual(callbacks.count, 1)
    }

    func testAddObserver_whenHangEndsAfterThresholdCrossed_shouldNotifyWithFinalDuration() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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
        XCTAssertEqual(beginInvocation.duration, 0.5)

        let endInvocation = try XCTUnwrap(callbacks.get(1))
        XCTAssertEqual(endInvocation.state, .ended)
        XCTAssertEqual(endInvocation.duration, 1.0)

        // Assert no additional invocations
        XCTAssertEqual(callbacks.count, 2)
    }

    func testAddObserver_whenHangEndsWithoutCrossingThreshold_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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

    func testAddObserver_whenTwoObserversWithDifferentThresholds_shouldNotifyIndependently() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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
        let lowHang = try XCTUnwrap(lowCallbacks.first)
        XCTAssertEqual(lowHang.duration, 0.5)
        XCTAssertEqual(lowHang.state, .started)
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
        let highHang = try XCTUnwrap(highCallbacks.first)
        XCTAssertEqual(highHang.duration, 3.0)
        XCTAssertEqual(highHang.state, .started)

        sut.removeObserver(token: token1)
        sut.removeObserver(token: token3)
    }

    func testAddObserver_whenConsecutiveHangs_shouldResetAndNotifyAgain() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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

        let firstStarted = try XCTUnwrap(callbacks.get(0))
        XCTAssertEqual(firstStarted.state, .started)
        XCTAssertEqual(firstStarted.duration, 0.5)

        let firstEnd = try XCTUnwrap(callbacks.get(1))
        XCTAssertEqual(firstEnd.state, .ended)
        XCTAssertEqual(firstEnd.duration, 0.8)

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        wait(for: [secondOngoing, secondEnded], timeout: 1)
        XCTAssertEqual(callbacks.count, 4)

        let secondStart = try XCTUnwrap(callbacks.get(2))
        XCTAssertEqual(secondStart.state, .started)
        XCTAssertEqual(secondStart.duration, 0.5)

        let secondEnd = try XCTUnwrap(callbacks.get(3))
        XCTAssertEqual(secondEnd.state, .ended)
        XCTAssertEqual(secondEnd.duration, 1.0)
    }

    func testRemoveObserver_whenDelayOccurs_shouldNotNotify() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
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

    func testRemoveObserver_whenRemovedMidHang_shouldNotReceiveEnded() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let removedCallbacks = Invocations<SentryAppHang>()
        let remainingCallbacks = Invocations<SentryAppHang>()
        let removedStarted = expectation(description: "Removed observer started")
        let remainingStarted = expectation(description: "Remaining observer started")
        let remainingEnded = expectation(description: "Remaining observer ended")
        let tokenToRemove = sut.addObserver(threshold: 0.25) { hang in
            removedCallbacks.record(hang)
            if hang.state == .started { removedStarted.fulfill() }
        }
        let tokenToKeep = sut.addObserver(threshold: 0.25) { hang in
            remainingCallbacks.record(hang)
            switch hang.state {
            case .started: remainingStarted.fulfill()
            case .ended: remainingEnded.fulfill()
            }
        }
        defer { sut.removeObserver(token: tokenToKeep) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [removedStarted, remainingStarted], timeout: 1)
        sut.removeObserver(token: tokenToRemove)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)

        // -- Assert --
        wait(for: [remainingEnded], timeout: 1)

        let removedHang = try XCTUnwrap(removedCallbacks.first)
        XCTAssertEqual(removedHang.state, .started)
        XCTAssertEqual(removedHang.duration, 0.5)

        let remainingStartHang = try XCTUnwrap(remainingCallbacks.get(0))
        XCTAssertEqual(remainingStartHang.state, .started)
        XCTAssertEqual(remainingStartHang.duration, 0.5)

        let remainingEndHang = try XCTUnwrap(remainingCallbacks.get(1))
        XCTAssertEqual(remainingEndHang.state, .ended)
        XCTAssertEqual(remainingEndHang.duration, 1.0)

        // Assert no additional invocations
        XCTAssertEqual(removedCallbacks.count, 1, "Removed observer should only have received .started")
        XCTAssertEqual(remainingCallbacks.count, 2)
    }

    func testAddObserver_whenAddedMidHang_shouldReceiveStartedOnNextTick() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let existingCallbacks = Invocations<SentryAppHang>()
        let lateCallbacks = Invocations<SentryAppHang>()
        let existingStarted = expectation(description: "Existing observer started")
        let token1 = sut.addObserver(threshold: 0.25) { hang in
            existingCallbacks.record(hang)
            if hang.state == .started { existingStarted.fulfill() }
        }
        defer { sut.removeObserver(token: token1) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [existingStarted], timeout: 1)

        let lateStarted = expectation(description: "Late observer started")
        let token2 = sut.addObserver(threshold: 0.25) { hang in
            lateCallbacks.record(hang)
            if hang.state == .started { lateStarted.fulfill() }
        }
        defer { sut.removeObserver(token: token2) }
        delayTracker.simulateDelay(duration: 0.8, ongoing: true)

        // -- Assert --
        wait(for: [lateStarted], timeout: 1)

        let existingHang = try XCTUnwrap(existingCallbacks.first)
        XCTAssertEqual(existingHang.duration, 0.5)

        let lateHang = try XCTUnwrap(lateCallbacks.first)
        XCTAssertEqual(lateHang.duration, 0.8)
        XCTAssertEqual(lateHang.state, .started)

        // Assert no additional invocations
        XCTAssertEqual(existingCallbacks.count, 1, "Existing observer should not be notified again")
        XCTAssertEqual(lateCallbacks.count, 1)
    }

    func testRemoveObserver_whenRemovedAndReaddedDuringHang_shouldReceiveFreshStarted() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let callbacks = Invocations<SentryAppHang>()
        let firstStarted = expectation(description: "First started")
        let keepAliveCallbacks = Invocations<SentryAppHang>()
        let tokenKeepAlive = sut.addObserver(threshold: 2.0) { hang in
            keepAliveCallbacks.record(hang)
        }
        defer { sut.removeObserver(token: tokenKeepAlive) }
        let token1 = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            if hang.state == .started { firstStarted.fulfill() }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [firstStarted], timeout: 1)
        sut.removeObserver(token: token1)

        let secondStarted = expectation(description: "Second started after re-add")
        let token2 = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            if hang.state == .started { secondStarted.fulfill() }
        }
        defer { sut.removeObserver(token: token2) }
        delayTracker.simulateDelay(duration: 0.8, ongoing: true)

        // -- Assert --
        wait(for: [secondStarted], timeout: 1)
        XCTAssertEqual(callbacks.count, 2, "Should have two .started invocations")

        let first = try XCTUnwrap(callbacks.get(0))
        XCTAssertEqual(first.state, .started)
        XCTAssertEqual(first.duration, 0.5)

        let second = try XCTUnwrap(callbacks.get(1))
        XCTAssertEqual(second.state, .started)
        XCTAssertEqual(second.duration, 0.8, "Re-added observer sees the later duration")
    }

    func testRemoveObserver_whenTokenAlreadyRemoved_shouldBeNoOp() {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let token = sut.addObserver(threshold: 0.25) { _ in }

        // -- Act & Assert --
        sut.removeObserver(token: token)
        sut.removeObserver(token: token)
    }

    // MARK: - Critical section tests

    func testHandler_whenCallingAddObserver_shouldNotDeadlock() throws {
        // Proves handlers are invoked outside the observers lock.
        // If they ran inside the lock, addObserver would re-enter the
        // non-reentrant os_unfair_lock and trap.

        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let innerCallbacks = Invocations<SentryAppHang>()
        var innerToken: SentryAppHangTrackerObserverToken?
        let outerNotified = expectation(description: "Outer handler fired")
        let innerNotified = expectation(description: "Inner handler fired")

        let outerToken = sut.addObserver(threshold: 0.25) { [weak sut] hang in
            guard let sut, hang.state == .started else { return }
            outerNotified.fulfill()
            innerToken = sut.addObserver(threshold: 0.25) { innerHang in
                innerCallbacks.record(innerHang)
                if innerHang.state == .started { innerNotified.fulfill() }
            }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [outerNotified], timeout: 1)
        delayTracker.simulateDelay(duration: 0.8, ongoing: true)

        // -- Assert --
        wait(for: [innerNotified], timeout: 1)
        let innerHang = try XCTUnwrap(innerCallbacks.first)
        XCTAssertEqual(innerHang.state, .started)

        sut.removeObserver(token: outerToken)
        if let innerToken { sut.removeObserver(token: innerToken) }
    }

    func testHandler_whenCallingSelfRemove_shouldNotDeadlock() {
        // Proves handlers are invoked outside the observers lock.
        // A handler that removes itself would trap if called under the lock.

        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let callbacks = Invocations<SentryAppHang>()
        let notified = expectation(description: "Handler fired")

        let keepAliveToken = sut.addObserver(threshold: 10.0) { _ in }

        var selfToken: SentryAppHangTrackerObserverToken!
        selfToken = sut.addObserver(threshold: 0.25) { [weak sut] hang in
            callbacks.record(hang)
            if hang.state == .started {
                sut?.removeObserver(token: selfToken)
                notified.fulfill()
            }
        }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [notified], timeout: 1)
        delayTracker.simulateDelay(duration: 0.8, ongoing: true)

        // -- Assert --
        XCTAssertEqual(callbacks.count, 1, "Self-removed observer must not receive further notifications")

        sut.removeObserver(token: keepAliveToken)
    }

    func testRemoveObserver_whenClosureDestroyed_shouldDestroyOutsideLock() {
        // Proves the removed ObserverEntry's closure is destroyed after the
        // lock is released. A sentinel object captured by the closure calls
        // back into the tracker from its deinit. If deinit ran while the lock
        // was held, os_unfair_lock would trap (non-reentrant).

        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let keepAliveToken = sut.addObserver(threshold: 10.0) { _ in }

        let deinitCalled = expectation(description: "Sentinel deinit called")

        var token: SentryAppHangTrackerObserverToken!
        autoreleasepool {
            let sentinel = DeinitSentinel(tracker: sut, onDeinit: { deinitCalled.fulfill() })
            token = sut.addObserver(threshold: 0.25) { [sentinel] _ in
                withExtendedLifetime(sentinel) {}
            }
        }

        // -- Act --
        sut.removeObserver(token: token)

        // -- Assert --
        wait(for: [deinitCalled], timeout: 1)

        sut.removeObserver(token: keepAliveToken)
    }

    func testProcessDelay_whenConcurrentWithAddRemove_shouldNotCrash() {
        // Stress-tests the SUT's mutex: a background thread fires processDelay
        // (via the mock) while the test thread adds/removes observers concurrently.

        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let iterations = 1_000
        let backgroundDone = expectation(description: "Background delays finished")

        var tokens: [SentryAppHangTrackerObserverToken] = []
        for _ in 0..<5 {
            let token = sut.addObserver(threshold: 0.1) { _ in }
            tokens.append(token)
        }

        // -- Act --
        DispatchQueue.global().async {
            for i in 0..<iterations {
                delayTracker.simulateDelay(duration: Double(i) * 0.001 + 0.2, ongoing: i % 3 != 0)
            }
            backgroundDone.fulfill()
        }

        for token in tokens {
            sut.removeObserver(token: token)
        }
        for _ in 0..<iterations {
            let token = sut.addObserver(threshold: 0.1) { _ in }
            sut.removeObserver(token: token)
        }

        // -- Assert --
        wait(for: [backgroundDone], timeout: 10)
    }

    // MARK: - Profiling Tests

    func testHangStarted_withProfiling_shouldIncludeProfilerId() throws {
        let delayTracker = MockSentryRunLoopDelayTracker()
        let deps = MockDependencies(runLoopDelayTracker: delayTracker)
        let options = SentryDefaultAppHangTracker<MockDependencies>.Options(sampleIntervalMs: 100)
        let sut = SentryDefaultAppHangTracker(dependencies: deps, profilingOptions: options)
        let callbacks = Invocations<SentryAppHang>()
        let expectation = expectation(description: "Observer notified")
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            expectation.fulfill()
        }
        defer { sut.removeObserver(token: token) }

        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [expectation], timeout: 1)

        let hang = try XCTUnwrap(callbacks.first)
        XCTAssertEqual(hang.state, .started)
        XCTAssertNotNil(hang.profilerId, "Started hang should include a profilerId when profiling is enabled")
    }

    func testHangEnded_withProfiling_shouldIncludeProfilingData() throws {
        let delayTracker = MockSentryRunLoopDelayTracker()
        let deps = MockDependencies(runLoopDelayTracker: delayTracker)
        let options = SentryDefaultAppHangTracker<MockDependencies>.Options(sampleIntervalMs: 100)
        let sut = SentryDefaultAppHangTracker(dependencies: deps, profilingOptions: options)
        let callbacks = Invocations<SentryAppHang>()
        let startedExpectation = expectation(description: "Started")
        let endedExpectation = expectation(description: "Ended")
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            switch hang.state {
            case .started: startedExpectation.fulfill()
            case .ended: endedExpectation.fulfill()
            }
        }
        defer { sut.removeObserver(token: token) }

        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [startedExpectation], timeout: 1)
        delayTracker.simulateDelay(duration: 1.0, ongoing: false)
        wait(for: [endedExpectation], timeout: 1)

        let endedHang = try XCTUnwrap(callbacks.get(1))
        XCTAssertEqual(endedHang.state, .ended)
        XCTAssertNotNil(endedHang.profilerId)
        XCTAssertNotNil(endedHang.profilingData, "Ended hang should include profiling data")
        XCTAssertGreaterThan(endedHang.profilingData?.samples.count ?? 0, 0, "Should have at least one sample")
    }

    func testHangEnded_withTwoObservers_bothReceiveProfilingData() throws {
        let delayTracker = MockSentryRunLoopDelayTracker()
        let deps = MockDependencies(runLoopDelayTracker: delayTracker)
        let options = SentryDefaultAppHangTracker<MockDependencies>.Options(sampleIntervalMs: 100)
        let sut = SentryDefaultAppHangTracker(dependencies: deps, profilingOptions: options)

        let callbacksA = Invocations<SentryAppHang>()
        let callbacksB = Invocations<SentryAppHang>()
        let startedA = expectation(description: "Observer A started")
        let endedA = expectation(description: "Observer A ended")
        let startedB = expectation(description: "Observer B started")
        let endedB = expectation(description: "Observer B ended")

        let tokenA = sut.addObserver(threshold: 0.25) { hang in
            callbacksA.record(hang)
            switch hang.state {
            case .started: startedA.fulfill()
            case .ended: endedA.fulfill()
            }
        }
        let tokenB = sut.addObserver(threshold: 0.25) { hang in
            callbacksB.record(hang)
            switch hang.state {
            case .started: startedB.fulfill()
            case .ended: endedB.fulfill()
            }
        }
        defer {
            sut.removeObserver(token: tokenA)
            sut.removeObserver(token: tokenB)
        }

        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [startedA, startedB], timeout: 1)

        delayTracker.simulateDelay(duration: 1.0, ongoing: false)
        wait(for: [endedA, endedB], timeout: 1)

        let endedHangA = try XCTUnwrap(callbacksA.get(1))
        let endedHangB = try XCTUnwrap(callbacksB.get(1))

        XCTAssertNotNil(endedHangA.profilerId, "Observer A should receive profilerId")
        XCTAssertNotNil(endedHangB.profilerId, "Observer B should receive profilerId")
        XCTAssertNotNil(endedHangA.profilingData, "Observer A should receive profiling data")
        XCTAssertNotNil(endedHangB.profilingData, "Observer B should receive profiling data")

        XCTAssertEqual(
            endedHangA.profilerId?.sentryIdString,
            endedHangB.profilerId?.sentryIdString,
            "Both observers should share the same profilerId"
        )
    }

    func testAddObserver_afterAllRemovedAndStopped_shouldStartFreshTracking() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let sut = SentryDefaultAppHangTracker(dependencies: MockDependencies(runLoopDelayTracker: delayTracker))
        let firstCallbacks = Invocations<SentryAppHang>()
        let firstStarted = expectation(description: "First started")
        let token1 = sut.addObserver(threshold: 0.25) { hang in
            firstCallbacks.record(hang)
            if hang.state == .started { firstStarted.fulfill() }
        }

        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        wait(for: [firstStarted], timeout: 1)
        sut.removeObserver(token: token1)

        // -- Act --
        let secondCallbacks = Invocations<SentryAppHang>()
        let secondStarted = expectation(description: "Second started after restart")
        let secondEnded = expectation(description: "Second ended after restart")
        let token2 = sut.addObserver(threshold: 0.25) { hang in
            secondCallbacks.record(hang)
            switch hang.state {
            case .started: secondStarted.fulfill()
            case .ended: secondEnded.fulfill()
            }
        }
        defer { sut.removeObserver(token: token2) }

        delayTracker.simulateDelay(duration: 0.5, ongoing: true)
        delayTracker.simulateDelay(duration: 0.8, ongoing: false)

        // -- Assert --
        wait(for: [secondStarted, secondEnded], timeout: 1)
        XCTAssertEqual(secondCallbacks.count, 2)

        let started = try XCTUnwrap(secondCallbacks.get(0))
        XCTAssertEqual(started.state, .started)
        XCTAssertEqual(started.duration, 0.5)

        let ended = try XCTUnwrap(secondCallbacks.get(1))
        XCTAssertEqual(ended.state, .ended)
        XCTAssertEqual(ended.duration, 0.8)
    }
}

private struct MockDependencies: SentryAppHangTrackerDependencies {
    let runLoopDelayTracker: SentryRunLoopDelayTracker
    var threadInspector: SentryThreadInspector { SentryThreadInspector(options: nil) }
    var dateProvider: SentryCurrentDateProvider { TestCurrentDateProvider() }
}

private class MockSentryRunLoopDelayTracker: SentryRunLoopDelayTracker {
    private let observers = SentryMutex<[SentryRunLoopDelayTrackerObserverToken: SentryRunLoopDelayTrackerHandler]>([:])

    func addObserver(handler: @escaping SentryRunLoopDelayTrackerHandler) -> SentryRunLoopDelayTrackerObserverToken {
        let token = SentryRunLoopDelayTrackerObserverToken()
        observers.withLock { $0[token] = handler }
        return token
    }

    func removeObserver(token: SentryRunLoopDelayTrackerObserverToken) {
        observers.withLock { _ = $0.removeValue(forKey: token) }
    }

    func simulateDelay(duration: TimeInterval, ongoing: Bool) {
        let snapshot = observers.withLock { Array($0.values) }
        for observer in snapshot {
            observer(.init(duration: duration, isOngoing: ongoing))
        }
    }
}

/// Sentinel whose deinit calls back into the tracker to acquire the observers lock.
/// If deinit runs while the lock is already held, os_unfair_lock traps (non-reentrant).
private class DeinitSentinel<Dependencies: SentryAppHangTrackerDependencies> {
    private weak var tracker: SentryDefaultAppHangTracker<Dependencies>?
    private let onDeinit: () -> Void

    init(tracker: SentryDefaultAppHangTracker<Dependencies>, onDeinit: @escaping () -> Void) {
        self.tracker = tracker
        self.onDeinit = onDeinit
    }

    deinit {
        if let tracker {
            let token = tracker.addObserver(threshold: 99.0) { _ in }
            tracker.removeObserver(token: token)
        }
        onDeinit()
    }
}
