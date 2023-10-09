import XCTest

final class SentryReachabilitySwiftTests: XCTestCase, SentryReachabilityObserver {

    func testAddRemoveFromMultipleThreads() throws {
        let sut = SentryReachability()
        testConcurrentModifications(writeWork: {_ in
            sut.add(self)
        }, readWork: {
            sut.remove(self)
        })
        
        sut.removeAllObservers()
    }
    
    func connectivityChanged(_ connected: Bool, typeDescription: String) {
        // Do nothing
    }

}
