@_spi(Private) @testable import Sentry
import XCTest

class TestSentryReachabilityObserver: NSObject, SentryReachabilityObserver {
    var connectivityChangedInvocations: UInt = 0
    var onReachabilityChanged: ((Bool, String) -> Void)?
    
    override init() {
        super.init()
        connectivityChangedInvocations = 0
    }
    
    func connectivityChanged(_ connected: Bool, typeDescription: String) {
        print("Received connectivity notification: \(connected); type: \(typeDescription)")
        connectivityChangedInvocations += 1
        onReachabilityChanged?(connected, typeDescription)
    }
}

final class SentryReachabilitySwiftTests: XCTestCase {
    
    private var reachability: SentryReachability!
    
    override func setUp() {
        super.setUp()
        // Ignore the actual reachability callbacks, cause we call the callbacks manually.
        // Otherwise, the actual reachability callbacks are called during later unrelated tests causing
        // flakes.
        reachability = SentryReachability()
        reachability.skipRegisteringActualCallbacks = true
        reachability.setReachabilityIgnoreActualCallback(true)
    }
    
    override func tearDown() {
        reachability.removeAllObservers()
        reachability.setReachabilityIgnoreActualCallback(false)
        reachability = nil
        super.tearDown()
    }
    
    func testConnectivityRepresentations() {
        XCTAssertEqual("none", SentryReachabilityTestHelper.stringForSentryConnectivity(.none))
        XCTAssertEqual("wifi", SentryReachabilityTestHelper.stringForSentryConnectivity(.wiFi))
        #if canImport(UIKit)
        XCTAssertEqual("cellular", SentryReachabilityTestHelper.stringForSentryConnectivity(.cellular))
        #endif
    }
    
    func testMultipleReachabilityObservers() {
        print("[Sentry] [TEST] creating observer A")
        let observerA = TestSentryReachabilityObserver()
        print("[Sentry] [TEST] adding observer A as reachability observer")
        reachability.add(observerA)
        
        print("[Sentry] [TEST] throwaway reachability callback, setting to reachable")
        reachability.triggerConnectivityCallback(.wiFi) // ignored, as it's the first callback
        print("[Sentry] [TEST] reachability callback set to unreachable")
        reachability.triggerConnectivityCallback(.none)
        
        print("[Sentry] [TEST] creating observer B")
        let observerB = TestSentryReachabilityObserver()
        print("[Sentry] [TEST] adding observer B as reachability observer")
        reachability.add(observerB)
        
        print("[Sentry] [TEST] reachability callback set back to reachable")
        reachability.triggerConnectivityCallback(.wiFi)
        print("[Sentry] [TEST] reachability callback set back to unreachable")
        reachability.triggerConnectivityCallback(.none)
        
        print("[Sentry] [TEST] removing observer B as reachability observer")
        reachability.remove(observerB)
        
        print("[Sentry] [TEST] reachability callback set back to reachable")
        reachability.triggerConnectivityCallback(.wiFi)
        
        XCTAssertEqual(5, observerA.connectivityChangedInvocations)
        XCTAssertEqual(2, observerB.connectivityChangedInvocations)
        
        print("[Sentry] [TEST] removing observer A as reachability observer")
        reachability.remove(observerA)
    }
    
    func testNoObservers() {
        let observer = TestSentryReachabilityObserver()
        reachability.add(observer)
        reachability.remove(observer)
        
        reachability.triggerConnectivityCallback(.wiFi)
        
        XCTAssertEqual(0, observer.connectivityChangedInvocations)
        
        reachability.removeAllObservers()
    }
    
    func testReportSameObserver_OnlyCalledOnce() {
        let observer = TestSentryReachabilityObserver()
        reachability.add(observer)
        reachability.add(observer)
        
        reachability.triggerConnectivityCallback(.wiFi)
        
        XCTAssertEqual(1, observer.connectivityChangedInvocations)
        
        reachability.remove(observer)
    }
    
    /// We only want to make sure running the actual registering and unregistering callbacks doesn't crash.
    func testRegisteringActualCallbacks() {
        reachability.skipRegisteringActualCallbacks = false
        
        let observer = TestSentryReachabilityObserver()
        
        reachability.add(observer)
        reachability.remove(observer)
    }
    
    func testAddRemoveFromMultipleThreads() throws {
        let sut = SentryReachability()
        // With this test, we want to test if the adding and removing
        // observers are adequately synchronized.
        sut.skipRegisteringActualCallbacks = true
        testConcurrentModifications(writeWork: { _ in
            sut.add(TestSentryReachabilityObserver())
        }, readWork: {
            sut.removeAllObservers()
        })
    }

    func testAddingAndRemovingObserversCleanTheMonitor() {
        reachability.skipRegisteringActualCallbacks = false
        reachability.setReachabilityIgnoreActualCallback(false)
        let observer = TestSentryReachabilityObserver()
        
        // Ensure starting scenario
        XCTAssertTrue(reachability.pathMonitorIsNil)
        
        // Do
        reachability.add(observer)
        
        // Verify
        // Monitor should not be nil when at least one observer is added
        XCTAssertFalse(reachability.pathMonitorIsNil)
        
        // Do again
        sleep(1)
        reachability.remove(observer)
        
        // Verify
        // Ensure when all observers are removed, the monitor is set to nil
        XCTAssertTrue(reachability.pathMonitorIsNil)
    }

    func testConnectivityCallbackAndRemoveAllObservers_NoDeadlock() {
        // This test reproduces the deadlock scenario where:
        // - Thread 1 holds instanceLock and calls removeAllObservers() (which needs observersLock)
        // - Thread 2 is in connectivityCallback() notifying observers
        // - Observer tries to access SentryDependencyContainer which needs instanceLock
        // The fix ensures observers are notified outside the observersLock

        let instanceLock = NSRecursiveLock() // Simulates SentryDependencyContainer.instanceLock

        let observerCallbackExpectation = expectation(description: "Observer callback completes")
        observerCallbackExpectation.expectedFulfillmentCount = 2
        let removeObserversExpectation = expectation(description: "removeAllObservers completes")
        let callbackStartedSemaphore = DispatchSemaphore(value: 0)

        let observer = TestSentryReachabilityObserver()
        observer.onReachabilityChanged = { _, _ in
            callbackStartedSemaphore.signal()

            // Wait a bit to ensure Thread 1 is trying to acquire observersLock
            Thread.sleep(forTimeInterval: 0.02)

            // This mimics SentryBreadcrumbTracker calling SentryDependencyContainer.sharedInstance()
            instanceLock.lock()
            instanceLock.unlock()

            observerCallbackExpectation.fulfill()
        }

        reachability.add(observer)
        reachability.triggerConnectivityCallback(.wiFi) // Initial state

        // Thread 1: Hold instanceLock and call removeAllObservers()
        // This simulates SentryDependencyContainer.reset() which holds instanceLock
        DispatchQueue.global().async {
            instanceLock.lock()

            // Wait for callback to start
            _ = callbackStartedSemaphore.wait(timeout: .now() + 1.0)

            // Give callback time to progress
            Thread.sleep(forTimeInterval: 0.01)

            // Now try to call removeAllObservers() while holding instanceLock
            // This will try to acquire observersLock - DEADLOCK if callback holds it while calling observer
            self.reachability.removeAllObservers()

            instanceLock.unlock()
            removeObserversExpectation.fulfill()
        }

        // Thread 2: Trigger connectivity callback
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.005) {
            self.reachability.triggerConnectivityCallback(.none)
        }

        // If there's a deadlock, this will timeout
        wait(for: [observerCallbackExpectation, removeObserversExpectation], timeout: 2.0)
    }
}
