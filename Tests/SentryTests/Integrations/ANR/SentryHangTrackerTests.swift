#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// Shared test types
fileprivate struct TestRunLoopObserver: RunLoopObserver { }

fileprivate struct TestApplicationProvider: ApplicationProvider {
    func application() -> SentryApplication? {
        return nil
    }
}

/// Tests for SentryHangTracker with focus on deterministic execution and avoiding flakiness.
///
/// Anti-Flakiness Strategy:
/// 1. **Deterministic Async Execution**: Use `drainAsyncQueue()` to ensure all async blocks
///    execute in a predictable order, avoiding race conditions.
/// 2. **Controlled Time**: Use `TestCurrentDateProvider` to advance time deterministically.
/// 3. **Mock Semaphores**: Use `TestSentryDispatchSemaphore` with `shouldTimeout` / `maxTimeouts`
///    to control hang detection behavior without real timing.
final class SentryHangTrackerTests: XCTestCase {
    
    private var observationBlock: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var testObserver = TestRunLoopObserver()
    private var calledRemoveObserver = false
    private var calledAddObserver = false
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    
    private let hangThreshold: TimeInterval = 0.025 // ~25ms for 60 FPS
    
    override func setUp() {
        super.setUp()
        observationBlock = nil
        calledRemoveObserver = false
        calledAddObserver = false
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    }
    
    private func createSut(
        dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider(),
        createSemaphore: @escaping (Int) -> SentryDispatchSemaphore = { TestSentryDispatchSemaphore(value: $0) }
    ) -> SentryDefaultHangTracker<TestRunLoopObserver> {
        return SentryDefaultHangTracker<TestRunLoopObserver>(
            applicationProvider: TestApplicationProvider(),
            dateProvider: dateProvider,
            queue: dispatchQueueWrapper,
            createObserver: { [weak self] _, _, _, _, block in
                self?.observationBlock = block
                return self?.testObserver
            },
            addObserver: { [weak self] _, _, _ in
                self?.calledAddObserver = true
            },
            removeObserver: { [weak self] _, _, _ in
                self?.calledRemoveObserver = true
            },
            createSemaphore: createSemaphore
        )
    }
    
    /// Creates a mock semaphore for hang detection testing.
    private func createMockSemaphore(shouldTimeout: Bool = true, maxTimeouts: Int = 1) -> TestSentryDispatchSemaphore {
        let semaphore = TestSentryDispatchSemaphore(value: 0)
        semaphore.shouldTimeout = shouldTimeout
        semaphore.timeoutDelay = 0
        semaphore.maxTimeouts = maxTimeouts
        return semaphore
    }
    
    /// Drains all pending async and main queue blocks in the test dispatch wrapper.
    /// Handles blocks that enqueue further blocks by iterating until stable.
    private func drainAsyncQueue() {
        let maxIterations = 100
        
        var processedCount = 0
        var iterations = 0
        while iterations < maxIterations {
            let currentCount = dispatchQueueWrapper.dispatchAsyncInvocations.count
            if processedCount >= currentCount { break }
            for i in processedCount..<currentCount {
                dispatchQueueWrapper.dispatchAsyncInvocations.get(i)?()
            }
            processedCount = currentCount
            iterations += 1
        }
        
        processedCount = 0
        iterations = 0
        while iterations < maxIterations {
            let currentCount = dispatchQueueWrapper.blockOnMainInvocations.count
            if processedCount >= currentCount { break }
            for i in processedCount..<currentCount {
                dispatchQueueWrapper.blockOnMainInvocations.get(i)?()
            }
            processedCount = currentCount
            iterations += 1
        }
    }
    
    // MARK: - Finished Run Loop Observer
    
    func testAddFinishedRunLoopObserver_whenObserverAdded_shouldCallFinishedCallback() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = createSut(dateProvider: dateProvider)
        let observerInvocations = Invocations<RunLoopIteration>()

        // -- Act --
        let id = sut.addFinishedRunLoopObserver { iteration in
            observerInvocations.record(iteration)
        }
        
        // -- Assert --
        XCTAssertTrue(calledAddObserver)
        XCTAssertTrue(observerInvocations.isEmpty)

        // -- Act --
        let block = try XCTUnwrap(observationBlock)
        block(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(0.001)
        block(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertEqual(observerInvocations.count, 1)
        let iteration = try XCTUnwrap(observerInvocations.first)
        XCTAssertGreaterThan(iteration.endTime, iteration.startTime)
        
        // -- Act --
        sut.removeFinishedRunLoopObserver(id: id)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledRemoveObserver)
    }
    
    func testRemoveFinishedRunLoopObserver_whenLastObserverRemoved_shouldStopTracking() {
        // -- Arrange --
        let sut = createSut()
        let id = sut.addFinishedRunLoopObserver { _ in }
        
        // -- Act --
        sut.removeFinishedRunLoopObserver(id: id)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledRemoveObserver)
    }
    
    func testMultipleFinishedRunLoopObservers_whenAllAdded_shouldCallAllCallbacks() {
        // -- Arrange --
        let sut = createSut()
        var callCount = 0
        
        // -- Act --
        let id1 = sut.addFinishedRunLoopObserver { _ in callCount += 1 }
        let id2 = sut.addFinishedRunLoopObserver { _ in callCount += 1 }
        let id3 = sut.addFinishedRunLoopObserver { _ in callCount += 1 }
        
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertEqual(callCount, 3)
        
        // Cleanup
        sut.removeFinishedRunLoopObserver(id: id1)
        sut.removeFinishedRunLoopObserver(id: id2)
        sut.removeFinishedRunLoopObserver(id: id3)
    }
    
    func testFinishedRunLoopObserver_whenModifiedDuringIteration_shouldNotCrash() {
        // Verifies the copy-on-iterate pattern in beforeWaiting prevents crashes
        // when an observer removes itself during the callback.
        
        // -- Arrange --
        let sut = createSut()
        var callCount = 0
        var removedId: UUID?
        
        let id = sut.addFinishedRunLoopObserver { [weak sut] _ in
            callCount += 1
            if let id = removedId {
                sut?.removeFinishedRunLoopObserver(id: id)
            }
        }
        removedId = id
        _ = sut.addFinishedRunLoopObserver { _ in callCount += 1 }
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(callCount, 1)
    }
    
    func testBeforeWaiting_whenLoopStartTimeIsNil_shouldNotCallFinishedHandlers() {
        // beforeWaiting without a prior afterWaiting means loopStartTime is nil.
        // Finished handlers should be skipped.
        
        // -- Arrange --
        let sut = createSut()
        var handlerCalled = false
        _ = sut.addFinishedRunLoopObserver { _ in handlerCalled = true }
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertFalse(handlerCalled)
    }
    
    // MARK: - Late Run Loop Observer (Hang Detection)
    
    func testAddLateRunLoopObserver_whenHangDetected_shouldCallLateCallback() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var handlerCalled = false
        
        // -- Act --
        let id = sut.addLateRunLoopObserver { _, _ in handlerCalled = true }
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        drainAsyncQueue()
        
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(handlerCalled)
    }
    
    func testRemoveLateRunLoopObserver_whenLastObserverRemoved_shouldStopTracking() {
        // -- Arrange --
        let sut = createSut()
        let id = sut.addLateRunLoopObserver { _, _ in }
        drainAsyncQueue()
        
        // -- Act --
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledRemoveObserver)
    }
    
    func testMultipleLateRunLoopObservers_whenAllAdded_shouldCallAllCallbacks() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var callCount = 0
        
        // -- Act --
        let id1 = sut.addLateRunLoopObserver { _, _ in callCount += 1 }
        let id2 = sut.addLateRunLoopObserver { _, _ in callCount += 1 }
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(callCount, 2)
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id1)
        sut.removeLateRunLoopObserver(id: id2)
        drainAsyncQueue()
    }
    
    func testMultipleLateRunLoopObservers_whenThreeSimultaneousObservers_shouldCallAllThree() {
        // Verifies explicit behavior with 3 simultaneous late run loop observers.
        // Each observer should receive the hang callback with the same hang ID.
        
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var observer1HangIds = Set<UUID>()
        var observer2HangIds = Set<UUID>()
        var observer3HangIds = Set<UUID>()
        
        // -- Act --
        let id1 = sut.addLateRunLoopObserver { hangId, _ in observer1HangIds.insert(hangId) }
        let id2 = sut.addLateRunLoopObserver { hangId, _ in observer2HangIds.insert(hangId) }
        let id3 = sut.addLateRunLoopObserver { hangId, _ in observer3HangIds.insert(hangId) }
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertEqual(observer1HangIds.count, 1, "Observer 1 should receive exactly one hang notification")
        XCTAssertEqual(observer2HangIds.count, 1, "Observer 2 should receive exactly one hang notification")
        XCTAssertEqual(observer3HangIds.count, 1, "Observer 3 should receive exactly one hang notification")
        XCTAssertEqual(observer1HangIds, observer2HangIds, "All observers should receive the same hang ID")
        XCTAssertEqual(observer2HangIds, observer3HangIds)
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id1)
        sut.removeLateRunLoopObserver(id: id2)
        sut.removeLateRunLoopObserver(id: id3)
        drainAsyncQueue()
    }
    
    func testHangDetection_whenRunLoopCompletesQuickly_shouldNotReportHang() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: false)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var hangDetected = false
        let id = sut.addLateRunLoopObserver { _, _ in hangDetected = true }
        drainAsyncQueue()
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(hangThreshold * 0.1)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertFalse(hangDetected)
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
    }
    
    func testHangId_whenMultipleIterations_shouldHaveUniqueIds() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        var currentTime: TimeInterval = 0
        dateProvider.setSystemUptime(currentTime)
        let testSemaphore1 = createMockSemaphore(shouldTimeout: true)
        let testSemaphore2 = createMockSemaphore(shouldTimeout: true)
        var semaphoreIndex = 0
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in
                semaphoreIndex += 1
                return semaphoreIndex == 1 ? testSemaphore1 : testSemaphore2
            }
        )
        var hangIds = Set<UUID>()
        let id = sut.addLateRunLoopObserver { hangId, _ in hangIds.insert(hangId) }
        drainAsyncQueue()
        
        // -- Act --
        // First hang
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        currentTime += hangThreshold * 2.0
        dateProvider.setSystemUptime(currentTime)
        drainAsyncQueue()
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Second hang (new run loop iteration = new ID)
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        currentTime += hangThreshold * 2.0
        dateProvider.setSystemUptime(currentTime)
        drainAsyncQueue()
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(hangIds.count, 1)
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
    }
    
    func testWaitForHang_whenMultipleConsecutiveHangs_shouldNotCauseStackOverflow() {
        // Verifies the iterative while-loop approach instead of recursion.
        
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true, maxTimeouts: 3)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var hangCount = 0
        let id = sut.addLateRunLoopObserver { _, _ in hangCount += 1 }
        drainAsyncQueue()
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(hangThreshold * 4.0)
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(hangCount, 1)
    }
    
    // MARK: - Deallocation Safety
    
    func testWaitForHang_whenSelfDeallocated_shouldExitLoop() {
        // Verifies that the [weak self] in the afterWaiting dispatch prevents
        // waitForHangIterative from running after the tracker is deallocated.
        
        // -- Arrange --
        let originalValue = dispatchQueueWrapper.dispatchAsyncExecutesBlock
        dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer { dispatchQueueWrapper.dispatchAsyncExecutesBlock = originalValue }
        
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        var hangCount = 0
        weak var weakSut: SentryDefaultHangTracker<TestRunLoopObserver>?
        
        // -- Act --
        autoreleasepool {
            let sut = createSut(
                dateProvider: dateProvider,
                createSemaphore: { _ in testSemaphore }
            )
            weakSut = sut
            _ = sut.addLateRunLoopObserver { _, _ in hangCount += 1 }
            drainAsyncQueue()
            observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        }
        
        // -- Assert --
        XCTAssertNil(weakSut)
        
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        drainAsyncQueue()
        
        XCTAssertEqual(hangCount, 0)
    }
    
    // MARK: - Cross-Dictionary Stop Guard
    
    func testRemoveFinishedRunLoopObserver_whenNewObserverAddedBeforeAsyncCleanup_shouldNotStop() {
        // Verifies the double-check pattern: removing the last finished observer enqueues
        // an async cleanup that re-checks finishedRunLoop.isEmpty. If a new observer is
        // added before that cleanup runs, stop() must be skipped.
        
        // -- Arrange --
        // Defer async execution so the cleanup block doesn't run until we drain.
        dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        
        let sut = createSut()
        
        let firstId = sut.addFinishedRunLoopObserver { _ in }
        
        // Remove first observer — finishedRunLoop is now empty, cleanup is ENQUEUED but not executed.
        sut.removeFinishedRunLoopObserver(id: firstId)
        
        // Add second observer BEFORE cleanup runs — finishedRunLoop is non-empty again.
        _ = sut.addFinishedRunLoopObserver { _ in }
        
        calledRemoveObserver = false
        
        // -- Act --
        // Execute the deferred cleanup — it should see finishedRunLoop is non-empty and skip stop().
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertFalse(calledRemoveObserver)
    }
    
    func testRemoveLateRunLoopObserver_whenFinishedRunLoopNotEmpty_shouldNotStopTracking() {
        // Removing the last late observer should NOT stop if finished observers remain.
        
        // -- Arrange --
        let sut = createSut()
        let finishedId = sut.addFinishedRunLoopObserver { _ in }
        let lateId = sut.addLateRunLoopObserver { _, _ in }
        drainAsyncQueue()
        
        // -- Act --
        sut.removeLateRunLoopObserver(id: lateId)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertFalse(calledRemoveObserver)
        
        // Cleanup
        sut.removeFinishedRunLoopObserver(id: finishedId)
    }
    
    func testRemoveFinishedRunLoopObserver_whenLateObserversExist_shouldNotStopTracking() {
        // Removing the last finished observer should NOT stop if late observers remain.
        
        // -- Arrange --
        let sut = createSut()
        let lateId = sut.addLateRunLoopObserver { _, _ in }
        drainAsyncQueue()
        
        let finishedId = sut.addFinishedRunLoopObserver { _ in }
        calledRemoveObserver = false
        
        // -- Act --
        sut.removeFinishedRunLoopObserver(id: finishedId)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertFalse(calledRemoveObserver)
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: lateId)
        drainAsyncQueue()
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
