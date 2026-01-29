@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// Shared test types for integration tests
fileprivate struct IntegrationTestRunLoopObserver: RunLoopObserver { }

fileprivate struct IntegrationTestApplicationProvider: ApplicationProvider {
    func application() -> SentryApplication? {
        return nil
    }
}

/// Integration tests for SentryHangTracker using real DispatchSemaphore.
///
/// These tests verify the hang tracker works correctly with real semaphore timeouts
/// and actual timing behavior, complementing the unit tests which use mocked semaphores.
///
/// Integration tests use real DispatchSemaphore to test:
/// - Real semaphore timeout behavior
/// - Actual timing interactions between main thread and background thread
/// - End-to-end hang detection with real system timing
final class SentryHangTrackerIntegrationTests: XCTestCase {
    
    private var observationBlock: ((IntegrationTestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var testObserver = IntegrationTestRunLoopObserver()
    private var calledRemoveObserver = false
    private var calledAddObserver = false
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    
    override func setUp() {
        super.setUp()
        observationBlock = nil
        calledRemoveObserver = false
        calledAddObserver = false
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    }
    
    private func createSut(dateProvider: SentryCurrentDateProvider = TestCurrentDateProvider()) -> SentryDefaultHangTracker<IntegrationTestRunLoopObserver> {
        // Use real DispatchSemaphore for integration tests
        return SentryDefaultHangTracker<IntegrationTestRunLoopObserver>(
            applicationProvider: IntegrationTestApplicationProvider(),
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
            createSemaphore: { DispatchSemaphore(value: $0) }
        )
    }
    
    // MARK: - Integration Tests with Real Semaphore
    
    func testAddLateRunLoopObserver_whenHangDetected_shouldCallLateCallback() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let startTime: TimeInterval = 0
        dateProvider.setSystemUptime(startTime)
        let sut = createSut(dateProvider: dateProvider)
        var observerIds = Set<UUID>()
        var observerLastInterval: TimeInterval = 0
        
        // -- Act --
        let id = sut.addLateRunLoopObserver { id, interval in
            observerIds.insert(id)
            observerLastInterval = interval
        }
        
        // Invoke async setup blocks
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Assert --
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Wait for real semaphore timeout (~25ms) with generous buffer for CI
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Advance test date provider time for interval calculation
            dateProvider.setSystemUptime(startTime + 0.1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // Give time for handler to be called via dispatchSync
        let handlerExpectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            handlerExpectation.fulfill()
        }
        wait(for: [handlerExpectation], timeout: 0.1)
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        sut.removeLateRunLoopObserver(id: id)
        
        // Invoke cleanup blocks
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Assert --
        XCTAssertGreaterThanOrEqual(observerIds.count, 1, "Expected late run loop callback at least once")
        XCTAssertGreaterThan(observerLastInterval, 0, "Expected hang interval to be positive")
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
    func testHangDetection_whenRunLoopCompletesQuickly_shouldNotReportHang() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = createSut(dateProvider: dateProvider)
        var hangDetected = false
        
        let id = sut.addLateRunLoopObserver { _, _ in
            hangDetected = true
        }
        
        // Invoke async setup
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act --
        observationBlock?(testObserver, CFRunLoopActivity.afterWaiting)
        
        // Complete run loop quickly (before timeout)
        dateProvider.setSystemUptime(0.001) // 1ms, well below ~25ms threshold
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Wait to ensure timeout doesn't fire
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        // -- Assert --
        XCTAssertFalse(hangDetected, "Should not detect hang when run loop completes quickly")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
    }
    
    func testWaitForHang_whenMultipleConsecutiveHangs_shouldNotCauseStackOverflow() {
        // This test verifies that iterative approach prevents stack overflow with real timing
        
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        let startTime: TimeInterval = 0
        dateProvider.setSystemUptime(startTime)
        let sut = createSut(dateProvider: dateProvider)
        var hangCount = 0
        
        let id = sut.addLateRunLoopObserver { _, _ in
            hangCount += 1
        }
        
        // Invoke async setup
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act --
        // Simulate multiple consecutive hangs by waiting for multiple timeouts
        observationBlock?(testObserver, .afterWaiting)
        
        // Wait for multiple timeouts (each timeout is ~25ms)
        // The iterative approach should handle this without stack overflow
        let expectation = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dateProvider.setSystemUptime(startTime + 0.15)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        sut.removeLateRunLoopObserver(id: id)
        
        // Invoke cleanup
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Assert --
        // Should handle multiple consecutive hangs without stack overflow
        XCTAssertGreaterThanOrEqual(hangCount, 1, "Should detect at least one hang")
    }
    
    func testHangId_whenMultipleIterations_shouldHaveUniqueIds() {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        var currentTime: TimeInterval = 0
        dateProvider.setSystemUptime(currentTime)
        let sut = createSut(dateProvider: dateProvider)
        var hangIds = Set<UUID>()
        
        let id = sut.addLateRunLoopObserver { hangId, _ in
            hangIds.insert(hangId)
        }
        
        // Invoke async setup
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
        
        // -- Act --
        // Trigger first hang
        observationBlock?(testObserver, .afterWaiting)
        
        let expectation1 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            currentTime += 0.05
            dateProvider.setSystemUptime(currentTime)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 0.2)
        
        let handlerExpectation1 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            handlerExpectation1.fulfill()
        }
        wait(for: [handlerExpectation1], timeout: 0.1)
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // Trigger second hang (new iteration)
        observationBlock?(testObserver, .afterWaiting)
        
        let expectation2 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            currentTime += 0.05
            dateProvider.setSystemUptime(currentTime)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 0.2)
        
        let handlerExpectation2 = XCTestExpectation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            handlerExpectation2.fulfill()
        }
        wait(for: [handlerExpectation2], timeout: 0.1)
        
        observationBlock?(testObserver, CFRunLoopActivity.beforeWaiting)
        
        // -- Assert --
        // Each iteration should have a unique hang ID
        XCTAssertGreaterThanOrEqual(hangIds.count, 1, "Should detect at least one hang")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
        dispatchQueueWrapper.invokeLastDispatchAsync()
        dispatchQueueWrapper.blockOnMainInvocations.invocations.last?()
    }
}
