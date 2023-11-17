import XCTest

final class SentryReachabilitySwiftTests: XCTestCase {

    func testAddRemoveFromMultipleThreads() throws {
        let sut = SentryReachability()
        // Calling the methods of SCNetworkReachability in a tight loop from
        // multiple threads is not an actual use case, and it leads to flaky test
        // results. With this test, we want to test if the adding and removing
        // observers are adequately synchronized and not if we call
        // SCNetworkReachability correctly.
        sut.skipRegisteringActualCallbacks = true
        testConcurrentModifications(writeWork: {_ in
            sut.add(TestReachabilityObserver())
        }, readWork: {
            sut.removeAllObservers()
        })
    }
}

class TestReachabilityObserver: NSObject, SentryReachabilityObserver {
    func connectivityChanged(_ connected: Bool, typeDescription: String) {
        // Do nothing
    }
}
