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
        let blockExpectation = XCTestExpectation(description: "Block Expectation")
        
        let outerExpectation = XCTestExpectation(description: "This exepctation should execute last")
        outerExpectation.isInverted = true
        
        let sut = SentryDispatchQueueWrapper()
        sut.dispatchAsyncOnMainQueueIfNotMainThread {
            XCTAssertTrue(Thread.isMainThread)
            self.wait(for: [outerExpectation], timeout: 1)
            
            blockExpectation.fulfill()
        }
        outerExpectation.fulfill()
        
        wait(for: [blockExpectation], timeout: 2)
    }
    
    func testDispatchAsyncOnMainQueueIfNotMainThreadFromBackground() {
        let expectation = XCTestExpectation()
        
        DispatchQueue.global().async {
            let mainThreadExpectation = XCTestExpectation(description: "Main Thread Expectation")
            let bgThreadExpectation = XCTestExpectation(description: "BG Thread Expectation")

            let sut = SentryDispatchQueueWrapper()

            sut.dispatchAsyncOnMainQueueIfNotMainThread {
                XCTAssertTrue(Thread.isMainThread, "The block didn't run on the main thread, but it should have")

                // Wait for the background thread to fulfill its expectation
                // If this code runs on the same thread as the bgThreadExpectation, the expectation times out.
                self.wait(for: [bgThreadExpectation], timeout: 5.0)

                // Unblock the BG thread
                mainThreadExpectation.fulfill()
            }

            // Unblock the main thread
            bgThreadExpectation.fulfill()

            self.wait(for: [mainThreadExpectation], timeout: 5.0)

            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
