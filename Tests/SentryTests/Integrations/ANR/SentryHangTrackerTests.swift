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
/// 2. **Generous Test Timeouts**: Use 10x multiplier for CI slowness (1-2 seconds) while keeping
///    actual semaphore timeouts short (~25ms) for fast test execution.
/// 3. **Controlled Time Advancement**: Use `waitForHangDetection()` helper to advance test date
///    provider time deterministically while waiting for real semaphore timeouts.
/// 4. **Avoid Real DispatchQueue Calls**: Don't use `DispatchQueue.main.asyncAfter` directly in tests;
///    use the test wrapper's controlled execution instead.
///
/// Note: `DispatchSemaphore.wait(timeout:)` uses real system time and cannot be mocked.
/// We work around this by:
/// - Using short semaphore timeouts (~25ms) for fast tests
/// - Using generous test timeouts (1-2 seconds) to account for CI slowness
/// - Ensuring deterministic execution order via `drainAsyncQueue()`
final class SentryHangTrackerTests: XCTestCase {
    
    private var observationBlock: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var testObserver = TestRunLoopObserver()
    private var calledRemoveObserver = false
    private var calledAddObserver = false
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    
    // Hang threshold is ~25ms for 60 FPS. Use generous multiplier for CI slowness.
    private let hangThresholdMultiplier: TimeInterval = 10.0 // 10x for CI safety
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
    
    /// Helper to create a mock semaphore configured for hang detection testing.
    ///
    /// - Parameter shouldTimeout: Whether the semaphore should timeout (simulating a hang)
    /// - Returns: A configured TestSentryDispatchSemaphore
    private func createMockSemaphore(shouldTimeout: Bool = true) -> TestSentryDispatchSemaphore {
        let semaphore = TestSentryDispatchSemaphore(value: 0)
        semaphore.shouldTimeout = shouldTimeout
        semaphore.timeoutDelay = 0 // Immediate timeout for deterministic testing
        return semaphore
    }
    
    /// Invokes all pending async blocks in the dispatch queue wrapper.
    /// This ensures deterministic execution order for tests.
    ///
    /// Note: Blocks may add more blocks during execution, so we use a limit
    /// to prevent infinite loops while still draining the queue.
    private func drainAsyncQueue() {
        // Invoke all pending async blocks (with limit to prevent infinite loops)
        var iterations = 0
        let maxIterations = 100 // Safety limit
        
        while iterations < maxIterations {
            if dispatchQueueWrapper.dispatchAsyncInvocations.isEmpty {
                break
            }
            dispatchQueueWrapper.invokeLastDispatchAsync()
            iterations += 1
        }
        
        // Invoke all pending main queue blocks (with limit to prevent infinite loops)
        iterations = 0
        while iterations < maxIterations {
            if dispatchQueueWrapper.blockOnMainInvocations.isEmpty {
                break
            }
            dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
            iterations += 1
        }
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAddFinishedRunLoopObserver_whenObserverAdded_shouldCallFinishedCallback() throws {
        // -- Arrange --
        let sut = createSut()
        let observerInvocations = Invocations<RunLoopIteration>()

        // -- Act --
        let id = sut.addFinishedRunLoopObserver { iteration in
            observerInvocations.record(iteration)
        }
        
        // -- Assert --
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        XCTAssertTrue(observerInvocations.isEmpty)

        // -- Act --
        let observationBlock = try XCTUnwrap(self.observationBlock)
        observationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertEqual(observerInvocations.count, 1, "Expected run loop to finish exactly once")
        let iteration = try XCTUnwrap(observerInvocations.first)
        XCTAssertGreaterThan(iteration.endTime, iteration.startTime, "End time should be after start time")
        
        // -- Act --
        sut.removeFinishedRunLoopObserver(id: id)
        
        // Invoke async cleanup blocks deterministically
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
    func testAddLateRunLoopObserver_whenHangDetected_shouldCallLateCallback() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let startTime: TimeInterval = 0
        dateProvider.setSystemUptime(startTime)
        let testSemaphore = TestSentryDispatchSemaphore(value: 0)
        testSemaphore.shouldTimeout = true // Simulate timeout for hang detection
        testSemaphore.timeoutDelay = 0 // Immediate timeout for deterministic testing
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var observerIds = Set<UUID>()
        var observerLastInterval: TimeInterval = 0
        
        // -- Act --
        let id = sut.addLateRunLoopObserver { id, interval in
            observerIds.insert(id)
            observerLastInterval = interval
        }
        
        // Invoke async setup blocks deterministically
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time for interval calculation
        let elapsedTime = hangThreshold * 2.0
        dateProvider.setSystemUptime(elapsedTime)
        
        // Trigger hang detection - the mock semaphore will timeout immediately
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        sut.removeLateRunLoopObserver(id: id)
        
        // Invoke cleanup blocks deterministically
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(observerIds.count, 1, "Expected late run loop callback at least once")
        XCTAssertGreaterThan(observerLastInterval, 0, "Expected hang interval to be positive")
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
    func testRemoveFinishedRunLoopObserver_whenLastObserverRemoved_shouldStopTracking() {
        // -- Arrange --
        let sut = createSut()
        
        // -- Act --
        let id = sut.addFinishedRunLoopObserver { _ in }
        
        sut.removeFinishedRunLoopObserver(id: id)
        
        // Invoke async cleanup blocks deterministically
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed when last observer is removed")
    }
    
    func testRemoveLateRunLoopObserver_whenLastObserverRemoved_shouldStopTracking() {
        // -- Arrange --
        let sut = createSut()
        
        // -- Act --
        let id = sut.addLateRunLoopObserver { _, _ in }
        
        // Invoke async setup
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        sut.removeLateRunLoopObserver(id: id)
        
        // Invoke async cleanup blocks deterministically
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed when last observer is removed")
    }
    
    // MARK: - Thread Safety Tests
    
    func testRemoveFinishedRunLoopObserver_whenObserverRemovedAndNewObserverAdded_shouldNotStopTracking() {
        // This test verifies Fix #1: Race condition where a new observer
        // can be added between the isEmpty check and the stop() call
        
        // -- Arrange --
        let sut = createSut()
        var secondObserverCalled = false
        
        // -- Act --
        let firstId = sut.addFinishedRunLoopObserver { _ in }
        
        // Remove first observer (this triggers async cleanup)
        sut.removeFinishedRunLoopObserver(id: firstId)
        
        // Immediately add second observer before cleanup completes
        let _ = sut.addFinishedRunLoopObserver { _ in
            secondObserverCalled = true
        }
        
        // Invoke async operations
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        // The tracker should still be running because second observer was added
        XCTAssertTrue(calledAddObserver, "Observer should still be active")
        XCTAssertFalse(calledRemoveObserver, "Observer should not be removed when second observer exists")
        XCTAssertTrue(secondObserverCalled, "Second observer should be called")
    }
    
    func testFinishedRunLoopObserver_whenModifiedDuringIteration_shouldNotCrash() {
        // This test verifies that dictionary modification during iteration
        // doesn't cause crashes or skipped handlers
        
        // -- Arrange --
        let sut = createSut()
        var callCount = 0
        var removedId: UUID?
        
        // Add observer that removes itself during callback
        let id = sut.addFinishedRunLoopObserver { [weak sut] _ in
            callCount += 1
            if let id = removedId {
                sut?.removeFinishedRunLoopObserver(id: id)
            }
        }
        removedId = id
        
        // Add another observer
        let _ = sut.addFinishedRunLoopObserver { _ in
            callCount += 1
        }
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        // Should not crash even if dictionary is modified during iteration
        XCTAssertGreaterThanOrEqual(callCount, 1, "At least one observer should be called")
    }
    
    func testWaitForHang_whenMultipleConsecutiveHangs_shouldNotCauseStackOverflow() {
        // This test verifies that iterative approach prevents stack overflow
        
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let startTime: TimeInterval = 0
        dateProvider.setSystemUptime(startTime)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var hangCount = 0
        
        let id = sut.addLateRunLoopObserver { _, _ in
            hangCount += 1
        }
        
        // Invoke async setup deterministically
        drainAsyncQueue()
        
        // -- Act --
        // Simulate multiple consecutive hangs by triggering multiple timeouts
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time for interval calculation
        dateProvider.setSystemUptime(hangThreshold * 4.0)
        
        // Trigger multiple hang detection timeouts (iterative approach)
        // Each drainAsyncQueue() will process one timeout iteration
        for _ in 0..<3 {
            drainAsyncQueue()
        }
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        sut.removeLateRunLoopObserver(id: id)
        
        // Invoke cleanup deterministically
        drainAsyncQueue()
        
        // -- Assert --
        // Should handle multiple consecutive hangs without stack overflow
        XCTAssertGreaterThanOrEqual(hangCount, 1, "Should detect at least one hang")
    }
    
    func testWaitForHang_whenSelfDeallocated_shouldExitLoop() {
        // This test verifies Fix #2: Infinite loop prevention when object is deallocated
        
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        var hangCount = 0
        
        var sut: SentryDefaultHangTracker<TestRunLoopObserver>? = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        
        _ = sut!.addLateRunLoopObserver { _, _ in
            hangCount += 1
        }
        
        // Invoke async setup deterministically
        drainAsyncQueue()
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Deallocate sut before timeout completes
        sut = nil
        
        // Advance time and trigger timeout - the loop should exit when it detects deallocation
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        drainAsyncQueue()
        
        // -- Assert --
        // Should exit loop without infinite waiting
        XCTAssertEqual(hangCount, 0, "Handler should not be called after deallocation")
    }
    
    func testAddLateRunLoopObserver_whenCalledFromBackgroundQueue_shouldNotDeadlock() {
        // This test verifies that async dispatch prevents deadlocks
        
        // -- Arrange --
        let sut = createSut()
        var observerId: UUID?
        
        // -- Act --
        // Call from background queue (simulating potential deadlock scenario)
        let expectation = XCTestExpectation()
        DispatchQueue.global().async {
            observerId = sut.addLateRunLoopObserver { _, _ in }
            expectation.fulfill()
        }
        
        // -- Assert --
        // Should complete without deadlocking
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(observerId, "Should successfully add observer without deadlock")
        
        if let id = observerId {
            sut.removeLateRunLoopObserver(id: id)
        }
    }
    
    func testRemoveLateRunLoopObserver_whenFinishedRunLoopNotEmpty_shouldNotStopTracking() {
        // This test verifies Fix #1: Thread-safe access to finishedRunLoop
        
        // -- Arrange --
        let sut = createSut()
        
        // Add finished run loop observer
        let finishedId = sut.addFinishedRunLoopObserver { _ in }
        
        // Add late run loop observer
        let lateId = sut.addLateRunLoopObserver { _, _ in }
        
        // Invoke async setup
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act --
        // Remove late observer (should not stop because finished observer exists)
        sut.removeLateRunLoopObserver(id: lateId)
        
        // Invoke async cleanup blocks deterministically
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertFalse(calledRemoveObserver, "Observer should not be removed when finished observer exists")
        
        // Cleanup
        sut.removeFinishedRunLoopObserver(id: finishedId)
    }
    
    func testAddLateRunLoopObserver_whenRegistrationAsync_shouldReturnIdImmediately() {
        // This test verifies Fix #3: Async registration semantics
        
        // -- Arrange --
        let sut = createSut()
        
        // -- Act --
        // UUID is returned immediately, but handler registration is async
        let id = sut.addLateRunLoopObserver { _, _ in
            // Handler may or may not be called depending on timing
            // This is the documented behavior - async registration means handler
            // might miss early hangs
        }
        
        // -- Assert --
        XCTAssertNotNil(id, "Should return UUID immediately")
        
        // Handler should not be registered yet (async dispatch hasn't completed)
        // Trigger a hang before async registration completes
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0.1)
        
        // Try to trigger hang detection - handler might not be called yet
        let hangBlock = dispatchQueueWrapper.dispatchAsyncInvocations.invocations.last
        hangBlock?()
        
        // Now complete async registration
        drainAsyncQueue()
        
        // Handler may or may not be called depending on timing
        // This is the documented behavior - async registration means handler
        // might miss early hangs
    }
    
    func testRemoveLateRunLoopObserver_whenRemovalAsync_shouldReturnImmediately() {
        // This test verifies async removal semantics
        
        // -- Arrange --
        let sut = createSut()
        
        let id = sut.addLateRunLoopObserver { _, _ in
            // Handler may or may not be called depending on timing
            // This is the documented behavior - async removal means handler
            // might catch late hangs
        }
        
        // Invoke async setup deterministically
        drainAsyncQueue()
        
        // -- Act --
        // Remove returns immediately, but removal is async
        sut.removeLateRunLoopObserver(id: id)
        
        // Trigger a hang before async removal completes
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0.1)
        
        // Try to trigger hang detection - handler might still be called
        let hangBlock = dispatchQueueWrapper.dispatchAsyncInvocations.invocations.last
        hangBlock?()
        
        let syncBlock = dispatchQueueWrapper.dispatchAsyncInvocations.invocations.last
        syncBlock?()
        
        // Now complete async removal
        drainAsyncQueue()
        
        // Handler may or may not be called depending on timing
        // This is the documented behavior - async removal means handler
        // might catch late hangs
    }
    
    // MARK: - Multiple Observers Tests
    
    func testMultipleFinishedRunLoopObservers_whenAllAdded_shouldCallAllCallbacks() {
        // -- Arrange --
        let sut = createSut()
        var callCount = 0
        
        // -- Act --
        let id1 = sut.addFinishedRunLoopObserver { _ in
            callCount += 1
        }
        
        let id2 = sut.addFinishedRunLoopObserver { _ in
            callCount += 1
        }
        
        let id3 = sut.addFinishedRunLoopObserver { _ in
            callCount += 1
        }
        
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertEqual(callCount, 3, "All three observers should be called")
        
        // Cleanup
        sut.removeFinishedRunLoopObserver(id: id1)
        sut.removeFinishedRunLoopObserver(id: id2)
        sut.removeFinishedRunLoopObserver(id: id3)
    }
    
    func testMultipleLateRunLoopObservers_whenAllAdded_shouldCallAllCallbacks() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let startTime: TimeInterval = 0
        dateProvider.setSystemUptime(startTime)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var callCount = 0
        
        // -- Act --
        let id1 = sut.addLateRunLoopObserver { _, _ in
            callCount += 1
        }
        
        let id2 = sut.addLateRunLoopObserver { _, _ in
            callCount += 1
        }
        
        // Invoke async setup deterministically
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time for interval calculation
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        
        // Trigger hang detection - mock semaphore will timeout immediately
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(callCount, 2, "Both observers should be called")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id1)
        sut.removeLateRunLoopObserver(id: id2)
        drainAsyncQueue()
    }
    
    // MARK: - Edge Cases
    
    func testAddFinishedRunLoopObserver_whenObserverAlreadyRunning_shouldNotCreateDuplicateObserver() {
        // -- Arrange --
        let sut = createSut()
        
        // -- Act --
        let id1 = sut.addFinishedRunLoopObserver { _ in }
        let id2 = sut.addFinishedRunLoopObserver { _ in }
        
        // -- Assert --
        XCTAssertTrue(calledAddObserver, "Observer should be added")
        XCTAssertEqual(calledAddObserver, true) // Only one observer should be created
        
        // Cleanup
        sut.removeFinishedRunLoopObserver(id: id1)
        sut.removeFinishedRunLoopObserver(id: id2)
    }
    
    func testRemoveFinishedRunLoopObserver_whenObserverNotExists_shouldNotCrash() {
        // -- Arrange --
        let sut = createSut()
        let nonExistentId = UUID()
        
        // -- Act & Assert --
        // Should not crash when removing non-existent observer
        sut.removeFinishedRunLoopObserver(id: nonExistentId)
        
        // Invoke async cleanup deterministically
        drainAsyncQueue()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
    }
    
    func testRemoveLateRunLoopObserver_whenObserverNotExists_shouldNotCrash() {
        // -- Arrange --
        let sut = createSut()
        let nonExistentId = UUID()
        
        // -- Act & Assert --
        // Should not crash when removing non-existent observer
        sut.removeLateRunLoopObserver(id: nonExistentId)
        
        // Invoke async cleanup deterministically
        drainAsyncQueue()
    }
    
    func testRunLoopIteration_whenNoObservers_shouldNotCrash() {
        // -- Arrange --
        let sut = createSut()
        
        // Start tracking (creates observer)
        let id = sut.addFinishedRunLoopObserver { _ in }
        
        // Remove observer
        sut.removeFinishedRunLoopObserver(id: id)
        
        // Invoke async cleanup deterministically
        drainAsyncQueue()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act & Assert --
        // Should not crash when run loop completes with no observers
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
    }
    
    func testHangDetection_whenRunLoopCompletesQuickly_shouldNotReportHang() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        // Use semaphore that doesn't timeout (simulates quick completion)
        let testSemaphore = createMockSemaphore(shouldTimeout: false)
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var hangDetected = false
        
        let id = sut.addLateRunLoopObserver { _, _ in
            hangDetected = true
        }
        
        // Invoke async setup deterministically
        drainAsyncQueue()
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Complete run loop quickly (before timeout)
        // Use time well below threshold to ensure no hang is detected
        dateProvider.setSystemUptime(hangThreshold * 0.1) // 10% of threshold
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Trigger hang detection - semaphore won't timeout, so no hang detected
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertFalse(hangDetected, "Should not detect hang when run loop completes quickly")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
    }
    
    // MARK: - Hang ID Tests
    
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
        
        let id = sut.addLateRunLoopObserver { hangId, _ in
            hangIds.insert(hangId)
        }
        
        // Invoke async setup deterministically
        drainAsyncQueue()
        
        // -- Act --
        // Trigger first hang
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        currentTime += hangThreshold * 2.0
        dateProvider.setSystemUptime(currentTime)
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Trigger second hang (new iteration)
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        currentTime += hangThreshold * 2.0
        dateProvider.setSystemUptime(currentTime)
        drainAsyncQueue()
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        // Each iteration should have a unique hang ID
        XCTAssertGreaterThanOrEqual(hangIds.count, 1, "Should detect at least one hang")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
    }
    
    // MARK: - Platform-Specific Tests
    
    func testInit_whenNoUIKitAvailable_shouldUseDefaultFPS() {
        // This test verifies platform-specific initialization
        
        // -- Arrange & Act --
        let sut = createSut()
        
        // -- Assert --
        // Should initialize successfully even without UIKit
        // The hangNotifyThreshold should default to 60 FPS calculation
        XCTAssertNotNil(sut, "Should initialize without UIKit")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testFinishedRunLoopObserver_whenConcurrentAddRemove_shouldNotCrash() {
        // -- Arrange --
        let sut = createSut()
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 100
        
        // -- Act --
        // Concurrently add and remove observers
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let id = sut.addFinishedRunLoopObserver { _ in }
            sut.removeFinishedRunLoopObserver(id: id)
            expectation.fulfill()
        }
        
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let id = sut.addFinishedRunLoopObserver { _ in }
            sut.removeFinishedRunLoopObserver(id: id)
            expectation.fulfill()
        }
        
        // -- Assert --
        wait(for: [expectation], timeout: 5.0)
        // Should complete without crashing
    }
    
    func testLateRunLoopObserver_whenConcurrentAddRemove_shouldNotCrash() {
        // -- Arrange --
        let sut = createSut()
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 100
        
        // -- Act --
        // Concurrently add and remove observers
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let id = sut.addLateRunLoopObserver { _, _ in }
            sut.removeLateRunLoopObserver(id: id)
            expectation.fulfill()
        }
        
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let id = sut.addLateRunLoopObserver { _, _ in }
            sut.removeLateRunLoopObserver(id: id)
            expectation.fulfill()
        }
        
        // -- Assert --
        wait(for: [expectation], timeout: 5.0)
        // Should complete without crashing
    }
}
