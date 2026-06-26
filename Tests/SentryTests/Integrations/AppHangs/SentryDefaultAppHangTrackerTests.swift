@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryDefaultAppHangTrackerTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeSUT(
        delayTracker: MockSentryRunLoopDelayTracker = MockSentryRunLoopDelayTracker(),
        threadInspector: MockSentryThreadInspector = MockSentryThreadInspector(),
        dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider(),
        profilingOptions: SentryDefaultAppHangTracker<MockDependencies>.Options = .init()
    ) -> (SentryDefaultAppHangTracker<MockDependencies>, MockSentryRunLoopDelayTracker, MockSentryThreadInspector) {
        let deps = MockDependencies(
            runLoopDelayTracker: delayTracker,
            threadInspector: threadInspector,
            dateProvider: dateProvider
        )
        let sut = SentryDefaultAppHangTracker(dependencies: deps, profilingOptions: profilingOptions)
        return (sut, delayTracker, threadInspector)
    }

    // MARK: - Existing Tests

    func testAddObserver_whenDelayExceedsThreshold_shouldNotifyObserver() throws {
        // -- Arrange --
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, delayTracker, _) = makeSUT()
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
        let (sut, _, _) = makeSUT()
        let token = sut.addObserver(threshold: 0.25) { _ in }

        // -- Act & Assert --
        sut.removeObserver(token: token)
        sut.removeObserver(token: token)
    }

    func testAddObserver_afterAllRemovedAndStopped_shouldStartFreshTracking() throws {
        // -- Arrange --
        let (sut, delayTracker, _) = makeSUT()
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

    // MARK: - Profiling Tests

    func testProcessDelay_whenHangEnds_profilingDataContainsSamples() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let threadInspector = MockSentryThreadInspector()
        threadInspector.stubbedThreads = [makeFakeMainThread(function: "main")]
        let (sut, _, _) = makeSUT(
            delayTracker: delayTracker,
            threadInspector: threadInspector,
            profilingOptions: .init(sampleIntervalMs: 50)
        )

        let callbacks = Invocations<SentryAppHang>()
        let startExpectation = expectation(description: "Hang started")
        let endExpectation = expectation(description: "Hang ended")

        var callCount = 0
        let token = sut.addObserver(threshold: 0.25) { hang in
            callbacks.record(hang)
            callCount += 1
            if callCount == 1 { startExpectation.fulfill() }
            if callCount == 2 { endExpectation.fulfill() }
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.3, ongoing: true)
        wait(for: [startExpectation], timeout: 1)

        // Let sampling timer fire a few times
        Thread.sleep(forTimeInterval: 0.2)

        delayTracker.simulateDelay(duration: 0.5, ongoing: false)
        wait(for: [endExpectation], timeout: 1)

        // -- Assert --
        let ended = try XCTUnwrap(callbacks.invocations.last)
        XCTAssertEqual(ended.state, .ended)
        XCTAssertNotNil(ended.profilerId)
        XCTAssertNotNil(ended.profilingData)

        let data = try XCTUnwrap(ended.profilingData)
        XCTAssertFalse(data.frames.isEmpty)
        XCTAssertFalse(data.stacks.isEmpty)
        XCTAssertFalse(data.samples.isEmpty)
    }

    func testProcessDelay_whenHangEnds_profilingDataDeduplicatesFrames() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let threadInspector = MockSentryThreadInspector()
        // Fixed stack: same frames each sample
        threadInspector.stubbedThreads = [makeFakeMainThread(function: "main")]
        let (sut, _, _) = makeSUT(
            delayTracker: delayTracker,
            threadInspector: threadInspector,
            profilingOptions: .init(sampleIntervalMs: 20)
        )

        let callbacks = Invocations<SentryAppHang>()
        let endExpectation = expectation(description: "Hang ended")

        let token = sut.addObserver(threshold: 0.1) { hang in
            callbacks.record(hang)
            if hang.state == .ended { endExpectation.fulfill() }
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.2, ongoing: true)
        Thread.sleep(forTimeInterval: 0.1)
        delayTracker.simulateDelay(duration: 0.5, ongoing: false)
        wait(for: [endExpectation], timeout: 1)

        // -- Assert --
        let data = try XCTUnwrap(callbacks.invocations.last?.profilingData)
        // Multiple samples but only one unique stack (all identical)
        XCTAssertGreaterThan(data.samples.count, 1)
        XCTAssertEqual(data.stacks.count, 1)
    }

    func testProcessDelay_whenHangStarts_profilingIdSetOnStartedEvent() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let (sut, _, _) = makeSUT(delayTracker: delayTracker)
        let callbacks = Invocations<SentryAppHang>()
        let startExpectation = expectation(description: "Hang started")
        let token = sut.addObserver(threshold: 0.1) { hang in
            callbacks.record(hang)
            if hang.state == .started { startExpectation.fulfill() }
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.2, ongoing: true)
        wait(for: [startExpectation], timeout: 1)

        // -- Assert --
        let started = try XCTUnwrap(callbacks.first)
        XCTAssertEqual(started.state, .started)
        XCTAssertNotNil(started.profilerId, "profilerId should be set on .started event")
        XCTAssertNil(started.profilingData, "profilingData should be nil on .started event")
    }

    func testProcessDelay_whenNoMainThreadFound_profilingDataIsNil() throws {
        // -- Arrange --
        let delayTracker = MockSentryRunLoopDelayTracker()
        let threadInspector = MockSentryThreadInspector()
        // Return empty threads — no main thread
        threadInspector.stubbedThreads = []
        let (sut, _, _) = makeSUT(
            delayTracker: delayTracker,
            threadInspector: threadInspector
        )

        let callbacks = Invocations<SentryAppHang>()
        let endExpectation = expectation(description: "Hang ended")
        let token = sut.addObserver(threshold: 0.1) { hang in
            callbacks.record(hang)
            if hang.state == .ended { endExpectation.fulfill() }
        }
        defer { sut.removeObserver(token: token) }

        // -- Act --
        delayTracker.simulateDelay(duration: 0.2, ongoing: true)
        delayTracker.simulateDelay(duration: 0.5, ongoing: false)
        wait(for: [endExpectation], timeout: 1)

        // -- Assert --
        let ended = try XCTUnwrap(callbacks.invocations.last)
        XCTAssertEqual(ended.state, .ended)
        // A profilerId is still created (SentryId is always generated), but profilingData is nil
        XCTAssertNil(ended.profilingData)
    }
}

// MARK: - Test Infrastructure

private func makeFakeMainThread(function: String) -> SentryThread {
    let frame = Frame()
    frame.function = function
    frame.instructionAddress = "0x000000008fd09c40"
    let stacktrace = SentryStacktrace(frames: [frame], registers: [:])
    let thread = SentryThread(threadId: 1)
    thread.isMain = true
    thread.stacktrace = stacktrace
    return thread
}

private struct MockDependencies: SentryAppHangTrackerDependencies {
    let runLoopDelayTracker: SentryRunLoopDelayTracker
    let threadInspector: SentryThreadInspector
    let dateProvider: SentryCurrentDateProvider
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

private class MockSentryThreadInspector: SentryThreadInspector {
    var stubbedThreads: [SentryThread] = []

    init() {
        super.init(options: nil)
    }

    override func getCurrentThreadsWithStackTrace() -> [SentryThread] {
        return stubbedThreads
    }
}
