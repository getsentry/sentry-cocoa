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
    
    func testDispatchAsyncOnMainQueueIfNotMainThreadOnMain() {
        let expectation = XCTestExpectation()
        
        var flag = false
        
        let sut = SentryDispatchQueueWrapper()
        sut.dispatchAsyncOnMainQueueIfNotMainThread {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertFalse(flag, "Block did not run synchronously")
            
            expectation.fulfill()
        }
        flag = true
        
        wait(for: [expectation], timeout: 2)
    }
    
    func testDispatchAsyncOnMainQueueIfNotMainThreadFromBackground() {
        let expectation = XCTestExpectation()
        
        DispatchQueue.global().async {
            let innerExpectation = XCTestExpectation(description: "Expectation on background thread")
            
            var flag = false
            let sut = SentryDispatchQueueWrapper()
            sut.dispatchAsyncOnMainQueueIfNotMainThread {
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(flag, "Block did not run asynchronously")
                
                innerExpectation.fulfill()
            }
            flag = true
            
            self.wait(for: [innerExpectation], timeout: 2)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
}
