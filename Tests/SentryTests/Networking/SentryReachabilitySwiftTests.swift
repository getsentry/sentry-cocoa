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
        // Calling the methods of SCNetworkReachability in a tight loop from
        // multiple threads is not an actual use case, and it leads to flaky test
        // results. With this test, we want to test if the adding and removing
        // observers are adequately synchronized and not if we call
        // SCNetworkReachability correctly.
        sut.skipRegisteringActualCallbacks = true
        testConcurrentModifications(writeWork: { _ in
            sut.add(TestSentryReachabilityObserver())
        }, readWork: {
            sut.removeAllObservers()
        })
    }

    /// This tests actually test NWPathMonitor response, if it becomes blaky we can disable it
    func testRegisteringActualCallbacks_CallbackIsCalled() {
        reachability.skipRegisteringActualCallbacks = false
        reachability.setReachabilityIgnoreActualCallback(false)
        
        let expectation = XCTestExpectation(description: "Callback should be called")
        
        let observer = TestSentryReachabilityObserver()
        observer.onReachabilityChanged = { _, _ in
            expectation.fulfill()
        }
        
        reachability.add(observer)
        
        wait(for: [expectation], timeout: 5)
    }
}
