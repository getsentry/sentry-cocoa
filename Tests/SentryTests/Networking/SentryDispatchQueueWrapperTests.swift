import _SentryPrivate
import XCTest

class SentryDispatchQueueWrapperTests: XCTestCase {

    func testDispatchOnce() {
        var a = 0
        
        var firstWasCalled = false
        var secondWasCalled = false
        var thirdWasCalled = false
        
        let sut = SentryDispatchQueueWrapper()
        sut.dispatchOnce(&a) {
            firstWasCalled = true
        }
        sut.dispatchOnce(&a) {
            secondWasCalled = true
        }
        
        var b = 0
        sut.dispatchOnce(&b) {
            thirdWasCalled = true
        }
        
        XCTAssertTrue(firstWasCalled)
        XCTAssertFalse(secondWasCalled)
        XCTAssertTrue(thirdWasCalled)
    }    
    
    func testDispatchSyncToMainThreadFromNonMainContext() {
        let e = expectation(description: "Asserted that execution happened on main thread")
        let sut = SentryDispatchQueueWrapper()
        sut.dispatchSyncOnMainQueue {
            XCTAssertTrue(Thread.isMainThread)
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testDispatchSyncToMainQueueFromNonMainContext() {
        let e = expectation(description: "Asserted that execution happened on main thread")
        let q = DispatchQueue(label: "a nonmain queue", qos: .background)
        q.async {
            XCTAssertFalse(Thread.isMainThread)
            let sut = SentryDispatchQueueWrapper()
            sut.dispatchSyncOnMainQueue {
                XCTAssertTrue(Thread.isMainThread)
                e.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }
}
