@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryRunLoopDelayTrackerTests: XCTestCase {

    private var createdObservationBlock: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var observationBlock: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var testObserver = TestRunLoopObserver()
    private var calledRemoveObserver = false
    private var calledAddObserver = false
    private let queue = DispatchQueue(label: "io.sentry.test-queue")

    override func setUp() {
        super.setUp()
        observationBlock = nil
        calledRemoveObserver = false
        calledAddObserver = false
    }

    private func createObserver(_ allocator: CFAllocator?, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex, _ block: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?) -> TestRunLoopObserver {
        createdObservationBlock = block
        return testObserver
    }

    private func addObserver(_ rl: CFRunLoop?, _ observer: TestRunLoopObserver?, _ mode: CFRunLoopMode?) {
        observationBlock = createdObservationBlock
        calledAddObserver = true
    }

    private func removeObserver(_ rl: CFRunLoop?, _ observer: TestRunLoopObserver?, _ mode: CFRunLoopMode?) {
        observationBlock = nil
        calledRemoveObserver = true
    }

  func testHangTrackerCallsRemoveObserverOnDealloc() {
      let mockDependencies = MockDependencies()
      var sut: SentryDefaultRunLoopDelayTracker? = SentryDefaultRunLoopDelayTracker(
        dependencies: mockDependencies,
        createObserver: createObserver,
        addObserver: addObserver,
        removeObserver: removeObserver,
        queue: queue)
    _ = sut?.addObserver { _ in }
      XCTAssertEqual(calledRemoveObserver, false)
      sut = nil
      XCTAssertEqual(calledRemoveObserver, true)
  }

    func testDoesNotCaptureHangsThatAreNotOngoing() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var observedHang = false
        let token = sut.addObserver { _ in
            observedHang = true
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")

        // Ensure the queue does not run until after the full runloop
        queue.suspend()
        observationBlock?(testObserver, .afterWaiting)
        // 10s passed, this is a hang
        mockDependencies.mockDateProvider.setSystemUptime(10)
        observationBlock?(testObserver, .beforeWaiting)

        // Start the queue again
        queue.resume()

        // This kind of hang is not caught, the hang observer is only called if
        // a hang was caught while it is *ongoing*. Sometimes we will only know
        // if a hang occurs after it's ended. It would be straightforward to add
        // support for that if we ever wanted it. But for now that API isn't needed.
        // It is best to keep that a separate API when we add it to make it clear which
        // thread the block gets called on.
        XCTAssertFalse(observedHang, "Should not observe hang")

        sut.removeObserver(token: token)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }

    func testHangTrackerWhenNotHanging() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var observedHang = false
        let token = sut.addObserver { _ in
            observedHang = true
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")

        // Ensure the queue does not run until after the full runloop
        queue.suspend()
        observationBlock?(testObserver, .afterWaiting)
        // 10 ms passed
        mockDependencies.mockDateProvider.setSystemUptime(0.01)
        observationBlock?(testObserver, .beforeWaiting)

        // Start the queue again
        queue.resume()

        XCTAssertFalse(observedHang, "Should not observe hang")

        sut.removeObserver(token: token)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }

    func testHangTrackerCallsLateRunLoop() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var observerLastInterval: TimeInterval = 0
        var hangOngoing: Bool = false
        let expectation = XCTestExpectation()
        let token = sut.addObserver { delay in
            observerLastInterval = delay.duration
            hangOngoing = delay.isOngoing
            expectation.fulfill()
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")

        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        wait(for: [expectation])

        // Note: We are writing to these variables on a bg thread but reading them here
        // on the main thread. This is safe without any locks because in our test
        // environment we know that there will not be any more modifications
        XCTAssertEqual(10, observerLastInterval, "Expected hang interval to be 10")
        XCTAssertTrue(hangOngoing)

        observationBlock?(testObserver, .beforeWaiting)

        let expectation2 = XCTestExpectation()
        queue.async {
            expectation2.fulfill()
        }
        wait(for: [expectation2])
        XCTAssertFalse(hangOngoing)

        sut.removeObserver(token: token)

        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }

    func testRemovesObserverDuringRunloop() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let token = sut.addObserver { _ in }
        observationBlock?(testObserver, .afterWaiting)
        sut.removeObserver(token: token)

        XCTAssertTrue(calledRemoveObserver, "Expected runloop to not be observed after last observer is removed")
        // Ensure the background queue isn't stuck waiting for another runloop event
        let expectation = XCTestExpectation()
        queue.async {
            expectation.fulfill()
        }
        // Ensure the queue is not blocked
        wait(for: [expectation])
    }

    func testHangTrackerDeallocates() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        var sut: SentryDefaultRunLoopDelayTracker? = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        #if swift(>=6.2)
        weak let weakSut = sut
        #else
        weak var weakSut = sut
        #endif

        _ = sut?.addObserver { _ in }
        observationBlock?(testObserver, .afterWaiting)
        observationBlock?(testObserver, .beforeWaiting)

        sut = nil

        // Allow the hang tracker's background thread to finish since it holds
        // a strong reference while it is running
        let expectation = XCTestExpectation()
        queue.async {
            expectation.fulfill()
        }
        wait(for: [expectation])

        XCTAssertNil(weakSut, "Expected observer to be deallocated")
    }

    /// Verifies that after one hang completes (ongoing=true then ongoing=false),
    /// a second hang is properly detected. This catches state-reset bugs with consecutive hangs.
    func testConsecutiveHangsAreDetected() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let lock = NSLock()
        var hangCount = 0
        var lastInterval: TimeInterval = 0
        var lastOngoing: Bool = false
        var hangCallback = XCTestExpectation()
        let token = sut.addObserver { delay in
            // Only fulfill one time
            lock.synchronized {
                if lastInterval == 0 {
                    hangCallback.fulfill()
                }
                lastInterval = delay.duration
                lastOngoing = delay.isOngoing
                if !delay.isOngoing {
                    hangCount += 1
                }
            }
        }

        // First hang: start
        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)
        wait(for: [hangCallback])

        lock.synchronized {
            XCTAssertEqual(lastInterval, 10, "First hang interval should be 10")
            XCTAssertTrue(lastOngoing, "First hang should be ongoing")
        }

        // First hang: complete
        observationBlock?(testObserver, .beforeWaiting)

        let firstHangEndExpectation = XCTestExpectation(description: "First hang ended")
        queue.async {
            firstHangEndExpectation.fulfill()
        }
        wait(for: [firstHangEndExpectation])

        // No need for the lock here, the background thread finished
        XCTAssertEqual(hangCount, 1, "First hang should be detected")
        XCTAssertFalse(lastOngoing, "First hang should no longer be ongoing")

        // Second hang: start (simulating another runloop iteration that hangs)
        mockDependencies.mockDateProvider.setSystemUptime(20)
        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(35) // 15 second hang

        lock.synchronized {
            hangCallback = XCTestExpectation(description: "Second hang detected")
            lastInterval = 0
        }
        wait(for: [hangCallback])

        lock.synchronized {
            XCTAssertEqual(lastInterval, 15, "Second hang interval should be 15")
            XCTAssertTrue(lastOngoing, "Second hang should be ongoing")
        }

        // Second hang: complete
        observationBlock?(testObserver, .beforeWaiting)

        let secondHangEndExpectation = XCTestExpectation(description: "Second hang ended")
        queue.async {
            secondHangEndExpectation.fulfill()
        }
        wait(for: [secondHangEndExpectation])

        // No need fo rthe lock here, the background thread finished
        XCTAssertEqual(hangCount, 2, "Second hang should be detected after first hang completed")
        XCTAssertFalse(lastOngoing, "Second hang should no longer be ongoing")

        sut.removeObserver(token: token)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }

    /// Verifies that when all references to HangTracker are nilled while the background queue
    /// is still in the waitForHang loop, the class does not deallocate until the loop exits,
    /// and then the dispatch queue is freed up (not blocked).
    func testDeallocWhileInWaitForHangLoop() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        var sut: SentryDefaultRunLoopDelayTracker? = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        #if swift(>=6.2)
        weak let weakSut = sut
        #else
        weak var weakSut = sut
        #endif

        let expectation = XCTestExpectation()
        var hangDetected = false
        _ = sut?.addObserver { _ in
            if !hangDetected {
                expectation.fulfill()
                hangDetected = true
            }
        }

        // Start the runloop iteration - this triggers the background queue to start waiting
        observationBlock?(testObserver, .afterWaiting)

        // Wait until the hang is detected
        wait(for: [expectation])

        // Now nil all references while the background queue is in the waitForHang loop
        // The HangTracker should NOT immediately deallocate because the background queue
        // holds a reference via the closure
        sut = nil

        XCTAssertNotNil(weakSut)

        observationBlock?(testObserver, .beforeWaiting)

        // Verify the queue is not blocked
        let queueFreeExpectation = XCTestExpectation(description: "Queue is free")
        queue.async {
            queueFreeExpectation.fulfill()
        }
        wait(for: [queueFreeExpectation])
        XCTAssertNil(weakSut)
        XCTAssertTrue(calledRemoveObserver)
    }

    func testRemoveOneOfMultipleObservers_remainingStillReceiveCallbacks() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var removedObserverCalled = false
        let token1 = sut.addObserver { _ in
            removedObserverCalled = true
        }

        var remainingInterval: TimeInterval = 0
        var remainingOngoing = false
        let remainingExpectation = XCTestExpectation(description: "Remaining observer called")
        let token2 = sut.addObserver { delay in
            if remainingInterval == 0 {
                remainingExpectation.fulfill()
            }
            remainingInterval = delay.duration
            remainingOngoing = delay.isOngoing
        }

        sut.removeObserver(token: token1)
        XCTAssertFalse(calledRemoveObserver, "Runloop observer should NOT be removed when other observers remain")

        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        wait(for: [remainingExpectation])

        XCTAssertFalse(removedObserverCalled, "Removed observer should not receive callbacks")
        XCTAssertEqual(remainingInterval, 10)
        XCTAssertTrue(remainingOngoing)

        observationBlock?(testObserver, .beforeWaiting)

        let endExpectation = XCTestExpectation(description: "Hang ended")
        queue.async { endExpectation.fulfill() }
        wait(for: [endExpectation])

        XCTAssertFalse(remainingOngoing)

        sut.removeObserver(token: token2)
        XCTAssertTrue(calledRemoveObserver, "Runloop observer should be removed after last observer is removed")
    }

    func testAddObserverDuringActiveHang_newObserverReceivesCallback() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var existingInterval: TimeInterval = 0
        let existingExpectation = XCTestExpectation(description: "Existing observer called")
        let token1 = sut.addObserver { delay in
            if existingInterval == 0 {
                existingExpectation.fulfill()
            }
            existingInterval = delay.duration
        }

        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        wait(for: [existingExpectation])

        var lateInterval: TimeInterval = 0
        var lateOngoing = false
        let lateExpectation = XCTestExpectation(description: "Late observer called")
        let token2 = sut.addObserver { delay in
            if lateInterval == 0 {
                lateExpectation.fulfill()
            }
            lateInterval = delay.duration
            lateOngoing = delay.isOngoing
        }

        wait(for: [lateExpectation])

        XCTAssertTrue(lateOngoing)
        XCTAssertGreaterThan(lateInterval, 0)

        observationBlock?(testObserver, .beforeWaiting)

        let endExpectation = XCTestExpectation(description: "Hang ended")
        queue.async { endExpectation.fulfill() }
        wait(for: [endExpectation])

        XCTAssertFalse(lateOngoing)

        sut.removeObserver(token: token1)
        sut.removeObserver(token: token2)
    }

    func testDoubleRemoveSameToken_shouldNotStopTracking() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var remainingInterval: TimeInterval = 0
        let remainingExpectation = XCTestExpectation(description: "Remaining observer called")
        let token1 = sut.addObserver { _ in }
        let token2 = sut.addObserver { delay in
            if remainingInterval == 0 {
                remainingExpectation.fulfill()
            }
            remainingInterval = delay.duration
        }

        sut.removeObserver(token: token1)
        XCTAssertFalse(calledRemoveObserver)

        sut.removeObserver(token: token1)
        XCTAssertFalse(calledRemoveObserver, "Double-removing should not trigger runloop observer removal")

        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        wait(for: [remainingExpectation])
        XCTAssertEqual(remainingInterval, 10)

        observationBlock?(testObserver, .beforeWaiting)

        let endExpectation = XCTestExpectation(description: "Hang ended")
        queue.async { endExpectation.fulfill() }
        wait(for: [endExpectation])

        sut.removeObserver(token: token2)
        XCTAssertTrue(calledRemoveObserver)
    }

    func testMultipleObserversAllReceiveHangCallback() {
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let lock = NSLock()
        var observer1Interval: TimeInterval = 0
        var observer1Ongoing: Bool = false
        var observer2Interval: TimeInterval = 0
        var observer2Ongoing: Bool = false
        var observer3Interval: TimeInterval = 0
        var observer3Ongoing: Bool = false

        let expectation1 = XCTestExpectation(description: "Observer 1 called")
        let expectation2 = XCTestExpectation(description: "Observer 2 called")
        let expectation3 = XCTestExpectation(description: "Observer 3 called")

        let token1 = sut.addObserver { delay in
            // Only fulfill one time
            if observer1Interval == 0 {
                expectation1.fulfill()
            }
            lock.synchronized {
                observer1Interval = delay.duration
                observer1Ongoing = delay.isOngoing
            }
        }
        let token2 = sut.addObserver { delay in
            // Only fulfill one time
            if observer2Interval == 0 {
                expectation2.fulfill()
            }
            lock.synchronized {
                observer2Interval = delay.duration
                observer2Ongoing = delay.isOngoing
            }
        }
        let token3 = sut.addObserver { delay in
            // Only fulfill one time
            if observer3Interval == 0 {
                expectation3.fulfill()
            }
            lock.synchronized {
                observer3Interval = delay.duration
                observer3Ongoing = delay.isOngoing
            }
        }

        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")

        // Trigger a hang
        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        wait(for: [expectation1, expectation2, expectation3])

        lock.synchronized {
            // All observers should have received the hang with same interval
            XCTAssertEqual(observer1Interval, 10, "Observer 1 should receive hang interval")
            XCTAssertEqual(observer2Interval, 10, "Observer 2 should receive hang interval")
            XCTAssertEqual(observer3Interval, 10, "Observer 3 should receive hang interval")

            XCTAssertTrue(observer1Ongoing, "Observer 1 should report hang as ongoing")
            XCTAssertTrue(observer2Ongoing, "Observer 2 should report hang as ongoing")
            XCTAssertTrue(observer3Ongoing, "Observer 3 should report hang as ongoing")
        }

        // End the hang
        observationBlock?(testObserver, .beforeWaiting)

        let hangEndExpectation = XCTestExpectation(description: "Hang ended")
        queue.async {
            hangEndExpectation.fulfill()
        }
        wait(for: [hangEndExpectation])

        // No need for the lock here because the hang is over
        // All observers should have been notified that the hang ended
        XCTAssertFalse(observer1Ongoing, "Observer 1 should report hang ended")
        XCTAssertFalse(observer2Ongoing, "Observer 2 should report hang ended")
        XCTAssertFalse(observer3Ongoing, "Observer 3 should report hang ended")

        sut.removeObserver(token: token1)
        sut.removeObserver(token: token2)
        sut.removeObserver(token: token3)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    // MARK: - Critical section tests

    func testHandler_whenCallingAddObserver_shouldNotDeadlock() {
        // Proves handlers are invoked outside the observers lock.
        // If they ran inside the lock, addObserver would re-enter the
        // non-reentrant os_unfair_lock and trap.

        // -- Arrange --
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let handlerFired = expectation(description: "Outer handler fired")
        let innerHandlerFired = expectation(description: "Inner handler fired")
        var innerToken: SentryRunLoopDelayTrackerObserverToken?
        var addedInner = false

        let outerToken = sut.addObserver { [weak sut] delay in
            guard let sut, delay.isOngoing, !addedInner else { return }
            addedInner = true
            handlerFired.fulfill()
            innerToken = sut.addObserver { innerDelay in
                if innerDelay.isOngoing { innerHandlerFired.fulfill() }
            }
        }

        // -- Act --
        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        // -- Assert --
        wait(for: [handlerFired], timeout: 2)

        wait(for: [innerHandlerFired], timeout: 2)

        observationBlock?(testObserver, .beforeWaiting)
        let queueDrained = expectation(description: "Queue drained")
        queue.async { queueDrained.fulfill() }
        wait(for: [queueDrained], timeout: 2)

        sut.removeObserver(token: outerToken)
        if let innerToken { sut.removeObserver(token: innerToken) }
    }

    func testHandler_whenCallingSelfRemove_shouldNotDeadlock() {
        // Proves handlers are invoked outside the observers lock.
        // A handler that removes itself would trap if called under the lock.

        // -- Arrange --
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let keepAliveToken = sut.addObserver { _ in }

        let handlerFired = expectation(description: "Self-removing handler fired")
        var selfToken: SentryRunLoopDelayTrackerObserverToken!
        var didRemoveSelf = false
        selfToken = sut.addObserver { [weak sut] delay in
            guard delay.isOngoing, !didRemoveSelf else { return }
            didRemoveSelf = true
            sut?.removeObserver(token: selfToken)
            handlerFired.fulfill()
        }

        // -- Act --
        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)

        // -- Assert --
        wait(for: [handlerFired], timeout: 2)

        observationBlock?(testObserver, .beforeWaiting)
        let queueDrained = expectation(description: "Queue drained")
        queue.async { queueDrained.fulfill() }
        wait(for: [queueDrained], timeout: 2)

        sut.removeObserver(token: keepAliveToken)
    }

    func testRemoveObserver_whenClosureDestroyed_shouldDestroyOutsideLock() {
        // Proves the removed handler closure is destroyed after the lock is
        // released. A sentinel captured by the closure calls back into the
        // tracker from its deinit — os_unfair_lock would trap if deinit ran
        // while the lock was held.

        // -- Arrange --
        let mockDependencies = MockDependencies()
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let keepAliveToken = sut.addObserver { _ in }

        let deinitCalled = expectation(description: "Sentinel deinit called")

        var token: SentryRunLoopDelayTrackerObserverToken!
        autoreleasepool {
            let sentinel = RunLoopDeinitSentinel(tracker: sut, onDeinit: { deinitCalled.fulfill() })
            token = sut.addObserver { [sentinel] _ in
                withExtendedLifetime(sentinel) {}
            }
        }

        // -- Act --
        sut.removeObserver(token: token)

        // -- Assert --
        wait(for: [deinitCalled], timeout: 1)

        sut.removeObserver(token: keepAliveToken)
    }

    func testWaitForDelay_whenConcurrentWithAddRemove_shouldNotCrash() {
        // Stress-tests the observers mutex: the background queue fires
        // waitForDelay while the main thread adds/removes observers.

        // -- Arrange --
        let mockDependencies = MockDependencies()
        mockDependencies.mockDateProvider.setSystemUptime(0)
        let sut = SentryDefaultRunLoopDelayTracker(
            dependencies: mockDependencies,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        let hangDetected = expectation(description: "Hang detected")
        var detected = false
        let token1 = sut.addObserver { delay in
            if delay.isOngoing && !detected {
                detected = true
                hangDetected.fulfill()
            }
        }

        // -- Act --
        observationBlock?(testObserver, .afterWaiting)
        mockDependencies.mockDateProvider.setSystemUptime(10)
        wait(for: [hangDetected], timeout: 2)

        for _ in 0..<200 {
            let token = sut.addObserver { _ in }
            sut.removeObserver(token: token)
        }

        observationBlock?(testObserver, .beforeWaiting)

        // -- Assert --
        let queueDrained = expectation(description: "Queue drained")
        queue.async { queueDrained.fulfill() }
        wait(for: [queueDrained], timeout: 2)

        sut.removeObserver(token: token1)
    }
}

/// Sentinel whose deinit calls back into the RunLoopDelayTracker to acquire
/// the observers lock. If deinit runs while the lock is held, os_unfair_lock traps.
private class RunLoopDeinitSentinel {
    private weak var tracker: SentryDefaultRunLoopDelayTracker<TestRunLoopObserver, MockDependencies>?
    private let onDeinit: () -> Void

    init(tracker: SentryDefaultRunLoopDelayTracker<TestRunLoopObserver, MockDependencies>, onDeinit: @escaping () -> Void) {
        self.tracker = tracker
        self.onDeinit = onDeinit
    }

    deinit {
        if let tracker {
            let token = tracker.addObserver { _ in }
            tracker.removeObserver(token: token)
        }
        onDeinit()
    }
}

private struct MockDependencies: SentryRunLoopDelayTrackerDependencies {
    let mockDateProvider = TestCurrentDateProvider()

    var dateProvider: any Sentry.SentryCurrentDateProvider {
        mockDateProvider
    }

    func application() -> (any Sentry.SentryApplication)? { nil }
}

private struct TestRunLoopObserver: SentryRunLoopObserver { }
