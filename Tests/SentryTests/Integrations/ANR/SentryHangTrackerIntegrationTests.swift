#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// Shared test types
fileprivate struct IntegrationTestApplicationProvider: ApplicationProvider {
    func application() -> SentryApplication? {
        return nil
    }
}

/// Helper class that manages a dedicated thread with its own CFRunLoop for testing.
///
/// This allows us to test hang detection end-to-end without interfering with the test
/// framework's main RunLoop. Each thread has its own RunLoop (per Apple's CFRunLoop docs).
///
/// - SeeAlso: https://developer.apple.com/documentation/corefoundation/cfrunloop
private class RunLoopThread {
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private let runLoopReady = DispatchSemaphore(value: 0)
    private let runLoopStopped = DispatchSemaphore(value: 0)
    
    /// Starts a new thread with its own RunLoop.
    /// Blocks until the RunLoop is ready.
    func start() {
        let thread = Thread { [weak self] in
            guard let self = self else { return }
            // Get this thread's RunLoop (each thread has its own)
            let currentRunLoop = CFRunLoopGetCurrent()
            self.runLoop = currentRunLoop
            
            // Add a dummy timer to keep the RunLoop alive.
            // The timer fires far in the future and repeats, keeping the RunLoop running.
            var timerContext = CFRunLoopTimerContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
            let timer = CFRunLoopTimerCreate(nil, CFAbsoluteTimeGetCurrent() + 1_000, 1_000, 0, 0, { _, _ in }, &timerContext)
            CFRunLoopAddTimer(currentRunLoop, timer, .commonModes)
            
            // Signal that RunLoop is ready
            self.runLoopReady.signal()
            
            // Run the RunLoop until stopped
            CFRunLoopRun()
            
            // Signal that RunLoop has stopped
            self.runLoopStopped.signal()
        }
        self.thread = thread
        thread.start()
        
        // Wait for RunLoop to be ready
        _ = runLoopReady.wait(timeout: .now() + 2.0)
    }
    
    /// Stops the RunLoop and cancels the thread.
    func stop() {
        guard let runLoop = runLoop else { return }
        CFRunLoopStop(runLoop)
        thread?.cancel()
        _ = runLoopStopped.wait(timeout: .now() + 2.0)
    }
    
    /// Returns the RunLoop for this thread.
    /// Must be called after `start()`.
    /// - Throws: If the RunLoop is not yet ready (e.g. `start()` was not called).
    func getRunLoop() throws -> CFRunLoop {
        try XCTUnwrap(runLoop, "RunLoop not ready. Call start() first.")
    }
    
    /// Schedules a block to execute on this thread's RunLoop.
    /// The RunLoop will wake up to process it.
    func performBlock(_ block: @escaping () -> Void) throws {
        let runLoop = try getRunLoop()
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }
}

/// Integration tests for SentryHangTracker using a secondary RunLoop on a dedicated thread.
///
/// These tests verify the full end-to-end chain: `CFRunLoopObserver -> semaphore timeout -> handler`.
/// By using a secondary RunLoop, we avoid interfering with the test framework's main RunLoop.
///
/// Everything is real — no mocks:
/// - Real `CFRunLoopObserver` (via `CFRunLoopObserverCreateWithHandler`)
/// - Real `SentryDispatchQueueWrapper` (real serial GCD queue)
/// - Real `DispatchSemaphore` (real timing behavior)
/// - Real `SentryCurrentDateProvider` (real wall-clock time)
///
/// The only injection is redirecting `addObserver`/`removeObserver` to the test thread's
/// RunLoop instead of the main RunLoop.
final class SentryHangTrackerIntegrationTests: XCTestCase {
    
    private var runLoopThread: RunLoopThread!
    
    override func setUp() {
        super.setUp()
        runLoopThread = RunLoopThread()
        runLoopThread.start()
    }
    
    override func tearDown() {
        runLoopThread?.stop()
        runLoopThread = nil
        super.tearDown()
    }
    
    private func createSut() throws -> SentryDefaultHangTracker<CFRunLoopObserver> {
        let testRunLoop = try runLoopThread.getRunLoop()
        
        return SentryDefaultHangTracker<CFRunLoopObserver>(
            applicationProvider: IntegrationTestApplicationProvider(),
            dateProvider: SentryDefaultCurrentDateProvider(),
            queue: SentryDispatchQueueWrapper(name: "io.sentry.hang-tracker.test"),
            createObserver: CFRunLoopObserverCreateWithHandler,
            addObserver: { _, observer, mode in
                // Redirect to the test RunLoop instead of main
                CFRunLoopAddObserver(testRunLoop, observer, mode)
            },
            removeObserver: { _, observer, mode in
                CFRunLoopRemoveObserver(testRunLoop, observer, mode)
            }
        )
    }
    
    /// Waits for async observer registration to complete.
    ///
    /// `addLateRunLoopObserver` dispatches to the serial queue, then to main.
    /// We spin the main RunLoop briefly to let both async steps finish.
    private func waitForRegistration() {
        let expectation = XCTestExpectation(description: "Registration complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Late Run Loop Observer (Hang Detection)
    
    func testHangDetection_shouldCallLateHandler() throws {
        // -- Arrange --
        let sut = try createSut()
        var handlerCalled = false
        var hangInterval: TimeInterval = 0
        
        let id = sut.addLateRunLoopObserver { _, interval in
            handlerCalled = true
            hangInterval = max(hangInterval, interval)
        }
        waitForRegistration()
        
        // -- Act --
        // Schedule blocking work on the test RunLoop to simulate a hang.
        // afterWaiting fires -> Thread.sleep blocks for 100ms -> beforeWaiting fires.
        // During the sleep, waitForHangIterative times out every ~8.3ms and calls handlers.
        try runLoopThread.performBlock {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Wait for the hang to complete plus a small buffer
        let expectation = XCTestExpectation(description: "Hang cycle complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertTrue(handlerCalled, "Handler should be called when hang is detected")
        XCTAssertGreaterThan(hangInterval, 0, "Hang interval should be positive")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
    }
    
    func testNoHang_whenRunLoopCompletesQuickly_shouldNotCallHandler() throws {
        // -- Arrange --
        let sut = try createSut()
        var handlerCalled = false
        
        let id = sut.addLateRunLoopObserver { _, _ in
            handlerCalled = true
        }
        waitForRegistration()
        
        // -- Act --
        // Schedule fast work (1ms, well below the ~25ms threshold)
        try runLoopThread.performBlock {
            Thread.sleep(forTimeInterval: 0.001)
        }
        
        // Wait to ensure any timeout would have fired
        let expectation = XCTestExpectation(description: "Wait for potential timeout")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertFalse(handlerCalled, "Handler should NOT be called when RunLoop completes quickly")
        
        // Cleanup
        sut.removeLateRunLoopObserver(id: id)
    }
    
    // MARK: - Finished Run Loop Observer
    
    func testFinishedRunLoopObserver_shouldCallHandler() throws {
        // -- Arrange --
        let sut = try createSut()
        var handlerCalled = false
        var iteration: RunLoopIteration?
        
        let id = sut.addFinishedRunLoopObserver { iter in
            handlerCalled = true
            iteration = iter
        }
        
        // -- Act --
        // Trigger one RunLoop iteration on the test thread.
        // afterWaiting fires -> block runs -> beforeWaiting fires (calls finished handler).
        let iterationExpectation = XCTestExpectation(description: "RunLoop iteration")
        try runLoopThread.performBlock {
            // Small sleep to ensure endTime > startTime
            Thread.sleep(forTimeInterval: 0.001)
            iterationExpectation.fulfill()
        }
        wait(for: [iterationExpectation], timeout: 1.0)
        
        // Small buffer for the beforeWaiting callback to fire
        let callbackExpectation = XCTestExpectation(description: "Callback processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            callbackExpectation.fulfill()
        }
        wait(for: [callbackExpectation], timeout: 1.0)
        
        // -- Assert --
        XCTAssertTrue(handlerCalled, "Handler should be called when RunLoop iteration completes")
        XCTAssertNotNil(iteration)
        if let iter = iteration {
            XCTAssertGreaterThan(iter.endTime, iter.startTime, "End time should be after start time")
        }
        
        // Cleanup
        sut.removeFinishedRunLoopObserver(id: id)
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
