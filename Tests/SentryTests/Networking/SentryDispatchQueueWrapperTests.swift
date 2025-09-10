import _SentryPrivate
@_spi(Private) @testable import Sentry
import XCTest

class SentryDispatchQueueWrapperSwiftTests: XCTestCase {

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
    
    func testQueueDispatchAsync() {
        let expectation = XCTestExpectation(description: "Executes")
        
        // This var is modified on the main thread after dispatching the block to verify the order oof execution
        var flag = false
        
        let sut = SentryDispatchQueueWrapper()
        sut.dispatchAsyncOnMainQueue {
            // Main queue is serial, so this should execute after the flag is toggled to true
            XCTAssertTrue(Thread.isMainThread)
            XCTAssert(flag, "Block did not run asynchronously")
            
            expectation.fulfill()
        }
        flag = true
        
        wait(for: [expectation], timeout: 10)
    }
}
