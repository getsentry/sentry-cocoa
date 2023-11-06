import XCTest

final class SentryReachabilitySwiftTests: XCTestCase {

    func testAddRemoveFromMultipleThreads() throws {
        let sut = SentryReachability()
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
