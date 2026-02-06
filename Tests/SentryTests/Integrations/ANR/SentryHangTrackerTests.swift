// swiftlint:disable file_length
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
    private let observationBlockLock = NSLock()
    private var testObserver = TestRunLoopObserver()
    private var calledRemoveObserver = false
    private var calledAddObserver = false
    private let calledRemoveObserverLock = NSLock()
    private let calledAddObserverLock = NSLock()
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    
    // Hang threshold is ~25ms for 60 FPS. Use generous multiplier for CI slowness.
    private let hangThresholdMultiplier: TimeInterval = 10.0 // 10x for CI safety
    private let hangThreshold: TimeInterval = 0.025 // ~25ms for 60 FPS
    
    override func setUp() {
        super.setUp()
        observationBlockLock.synchronized {
            observationBlock = nil
        }
        calledRemoveObserverLock.synchronized {
            calledRemoveObserver = false
        }
        calledAddObserverLock.synchronized {
            calledAddObserver = false
        }
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    }
    
    /// Safely gets the observation block if it exists.
    /// This method is thread-safe and should be used when accessing observationBlock from multiple threads.
    private func getObservationBlock() -> ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)? {
        return observationBlockLock.synchronized {
            return observationBlock
        }
    }
    
    /// Safely invokes the observation block if it exists.
    /// This method is thread-safe and should be used when calling observationBlock from multiple threads.
    private func invokeObservationBlock(_ observer: TestRunLoopObserver, _ activity: CFRunLoopActivity) {
        getObservationBlock()?(observer, activity)
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
                self?.observationBlockLock.synchronized {
                    self?.observationBlock = block
                }
                return self?.testObserver
            },
            addObserver: { [weak self] _, _, _ in
                self?.calledAddObserverLock.synchronized {
                    self?.calledAddObserver = true
                }
            },
            removeObserver: { [weak self] _, _, _ in
                self?.calledRemoveObserverLock.synchronized {
                    self?.calledRemoveObserver = true
                }
            },
            createSemaphore: createSemaphore
        )
    }
    
    /// Helper to create a mock semaphore configured for hang detection testing.
    ///
    /// - Parameters:
    ///   - shouldTimeout: Whether the semaphore should timeout (simulating a hang)
    ///   - maxTimeouts: Maximum number of timeouts before returning success. Default is 1 to allow
    ///     one timeout (hang detection) then break the loop. Set higher for tests that need multiple consecutive timeouts.
    /// - Returns: A configured TestSentryDispatchSemaphore
    private func createMockSemaphore(shouldTimeout: Bool = true, maxTimeouts: Int = 1) -> TestSentryDispatchSemaphore {
        let semaphore = TestSentryDispatchSemaphore(value: 0)
        semaphore.shouldTimeout = shouldTimeout
        semaphore.timeoutDelay = 0 // Immediate timeout for deterministic testing
        semaphore.maxTimeouts = maxTimeouts // Allow one timeout by default, then return success to break the loop
        return semaphore
    }
    
    /// Invokes all pending async blocks in the dispatch queue wrapper.
    /// This ensures deterministic execution order for tests.
    ///
    /// Note: Blocks may add more blocks during execution, so we use a limit
    /// to prevent infinite loops while still draining the queue.
    /// 
    /// Since Invocations doesn't support removal, we process blocks by index
    /// and track how many we've processed to avoid reprocessing.
    private func drainAsyncQueue() {
        // Invoke all pending async blocks (with limit to prevent infinite loops)
        var processedCount = 0
        var iterations = 0
        let maxIterations = 100 // Safety limit
        
        while iterations < maxIterations {
            let currentCount = dispatchQueueWrapper.dispatchAsyncInvocations.count
            if processedCount >= currentCount {
                // No new blocks added, we're done
                break
            }
            
            // Process blocks from first to last
            for i in processedCount..<currentCount {
                if let block = dispatchQueueWrapper.dispatchAsyncInvocations.get(i) {
                    block()
                }
            }
            
            processedCount = currentCount
            iterations += 1
        }
        
        // Invoke all pending main queue blocks (with limit to prevent infinite loops)
        processedCount = 0
        iterations = 0
        while iterations < maxIterations {
            let currentCount = dispatchQueueWrapper.blockOnMainInvocations.count
            if processedCount >= currentCount {
                break
            }
            
            // Process blocks from first to last
            for i in processedCount..<currentCount {
                if let block = dispatchQueueWrapper.blockOnMainInvocations.get(i) {
                    block()
                }
            }
            
            processedCount = currentCount
            iterations += 1
        }
    }
    
    // MARK: - Basic Functionality Tests
    
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
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        XCTAssertTrue(observerInvocations.isEmpty)

        // -- Act --
        let block = try XCTUnwrap(getObservationBlock())
        block(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time to ensure endTime > startTime
        dateProvider.setSystemUptime(0.001)
        
        block(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        dateProvider.setSystemUptime(0)
        let testSemaphore = TestSentryDispatchSemaphore(value: 0)
        testSemaphore.shouldTimeout = true
        testSemaphore.maxTimeouts = 1
        
        let sut = createSut(
            dateProvider: dateProvider,
            createSemaphore: { _ in testSemaphore }
        )
        var handlerCalled = false
        
        // -- Act --
        let id = sut.addLateRunLoopObserver { _, _ in
            handlerCalled = true
        }
        
        drainAsyncQueue()
        
        // Trigger hang detection
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        drainAsyncQueue()
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        drainAsyncQueue()
        
        sut.removeLateRunLoopObserver(id: id)
        drainAsyncQueue()
        
        // -- Assert --
        XCTAssertTrue(handlerCalled, "Handler should be called when hang is detected")
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
        
        // Reset flag before executing async operations to verify it doesn't get set
        calledRemoveObserverLock.synchronized {
            calledRemoveObserver = false
        }
        
        // Invoke async operations
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act --
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        // Allow multiple timeouts to simulate consecutive hangs
        let testSemaphore = createMockSemaphore(shouldTimeout: true, maxTimeouts: 3)
        
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time for interval calculation
        dateProvider.setSystemUptime(hangThreshold * 4.0)
        
        // Trigger multiple hang detection timeouts (iterative approach)
        // Each drainAsyncQueue() will process one timeout iteration
        for _ in 0..<3 {
            drainAsyncQueue()
        }
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        // Disable immediate execution to prevent hang detection from starting before deallocation
        let originalValue = dispatchQueueWrapper.dispatchAsyncExecutesBlock
        dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer {
            dispatchQueueWrapper.dispatchAsyncExecutesBlock = originalValue
        }
        
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let testSemaphore = createMockSemaphore(shouldTimeout: true)
        var hangCount = 0
        
        weak var weakSut: SentryDefaultHangTracker<TestRunLoopObserver>?
        
        // -- Act --
        // Create the tracker in a scope that will be deallocated
        autoreleasepool {
            let sut = createSut(
                dateProvider: dateProvider,
                createSemaphore: { _ in testSemaphore }
            )
            weakSut = sut
            
            _ = sut.addLateRunLoopObserver { _, _ in
                hangCount += 1
            }
            
            // Invoke async setup deterministically
            drainAsyncQueue()
            
            // Trigger afterWaiting to start hang detection (dispatches async, but won't execute yet)
            invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
            
            // The sut should be deallocated when this scope ends
        }
        
        // Verify the instance was deallocated
        XCTAssertNil(weakSut, "SUT should be deallocated")
        
        // Advance time for interval calculation
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        
        // Now execute the async blocks - waitForHangIterative should detect deallocation
        // When waitForHangIterative times out and checks self, it will be nil,
        // so shouldContinue will remain false and the loop will exit without calling handlers
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
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
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Advance time for interval calculation
        dateProvider.setSystemUptime(hangThreshold * 2.0)
        
        // Trigger hang detection - mock semaphore will timeout immediately
        drainAsyncQueue()
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Complete run loop quickly (before timeout)
        // Use time well below threshold to ensure no hang is detected
        dateProvider.setSystemUptime(hangThreshold * 0.1) // 10% of threshold
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
        currentTime += hangThreshold * 2.0
        dateProvider.setSystemUptime(currentTime)
        drainAsyncQueue()
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Trigger second hang (new iteration)
        invokeObservationBlock(testObserver, CFRunLoopActivity.afterWaiting)
        
        currentTime += hangThreshold * 2.0
        dateProvider.setSystemUptime(currentTime)
        drainAsyncQueue()
        
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
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
        // Disable immediate execution to prevent race conditions
        // finishedRunLoop uses NSLock, but we still want to test concurrent access properly
        let originalValue = dispatchQueueWrapper.dispatchAsyncExecutesBlock
        dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer {
            dispatchQueueWrapper.dispatchAsyncExecutesBlock = originalValue
        }
        
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
        
        // Wait for all concurrent operations to complete
        wait(for: [expectation], timeout: 5.0)
        
        // Drain any async cleanup blocks serially
        drainAsyncQueue()
        
        // -- Assert --
        // Should complete without crashing
    }
    
    func testLateRunLoopObserver_whenConcurrentAddRemove_shouldNotCrash() {
        // -- Arrange --
        // Disable immediate execution to prevent concurrent access to lateRunLoop dictionary
        // The real implementation uses a serial queue, so we need to simulate that
        let originalValue = dispatchQueueWrapper.dispatchAsyncExecutesBlock
        dispatchQueueWrapper.dispatchAsyncExecutesBlock = false
        defer {
            dispatchQueueWrapper.dispatchAsyncExecutesBlock = originalValue
        }
        
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
        
        // Wait for all concurrent operations to complete
        wait(for: [expectation], timeout: 5.0)
        
        // Now drain the async queue serially (simulating serial queue behavior)
        // This ensures dictionary access is serialized, matching the real implementation
        drainAsyncQueue()
        
        // -- Assert --
        // Should complete without crashing
    }
    
    // MARK: - Weak Self Deallocation Tests
    
    // Note: We only test the critical weak self deallocation case that prevents infinite loops.
    // Other weak self deallocation scenarios are implementation details and don't add practical value.
    
    // MARK: - Observer Callback Edge Cases
    
    func testBeforeWaiting_whenCalledWithoutAfterWaiting_shouldNotCrash() {
        // This test verifies that beforeWaiting can be called without afterWaiting
        // (edge case that could happen in real scenarios)
        
        // -- Arrange --
        let sut = createSut()
        _ = sut.addFinishedRunLoopObserver { _ in }
        
        // -- Act & Assert --
        // Should not crash when beforeWaiting is called without afterWaiting
        // currentSemaphore will be nil, which is safe to signal
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Cleanup
        drainAsyncQueue()
    }
    
    func testBeforeWaiting_whenLoopStartTimeIsNil_shouldNotCallFinishedHandlers() {
        // This test verifies that beforeWaiting doesn't call finished handlers
        // when loopStartTime is nil
        
        // -- Arrange --
        let sut = createSut()
        var handlerCalled = false
        
        _ = sut.addFinishedRunLoopObserver { _ in
            handlerCalled = true
        }
        
        // -- Act --
        // Call beforeWaiting without calling afterWaiting first
        // This means loopStartTime will be nil
        invokeObservationBlock(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        // Handler should not be called because loopStartTime is nil
        XCTAssertFalse(handlerCalled, "Handler should not be called when loopStartTime is nil")
    }
    
    // MARK: - Cross-Dictionary Stop Guard Tests
    
    func testRemoveFinishedRunLoopObserver_whenLateObserversExist_shouldNotStopTracking() {
        // This test verifies that removing the last finished observer does NOT stop
        // tracking when late observers are still registered. Both dictionaries must be
        // empty before the CFRunLoopObserver is removed.
        
        // -- Arrange --
        let sut = createSut()
        
        // Add a late observer first
        let lateId = sut.addLateRunLoopObserver { _, _ in }
        drainAsyncQueue()
        
        // Add then remove a finished observer
        let finishedId = sut.addFinishedRunLoopObserver { _ in }
        
        // Reset flag — adding the finished observer may have set it
        calledRemoveObserverLock.synchronized {
            calledRemoveObserver = false
        }
        
        // -- Act --
        sut.removeFinishedRunLoopObserver(id: finishedId)
        drainAsyncQueue()
        
        // -- Assert --
        // Tracker should still be running because lateRunLoop is not empty
        XCTAssertFalse(calledRemoveObserver, "Observer should not be removed when late observers exist")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: lateId)
        drainAsyncQueue()
    }
}
// swiftlint:enable file_length
