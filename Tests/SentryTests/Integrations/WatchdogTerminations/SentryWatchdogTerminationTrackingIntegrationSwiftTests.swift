@_spi(Private) @testable import Sentry
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import XCTest

final class TestHangTracker: HangTracker {
    
    var lateRunloopObserver: ((UUID, TimeInterval) -> Void)?
    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID {
        lateRunloopObserver = handler
        return UUID()
    }
    
    var removedLateRunloopObserver: UUID?
    func removeLateRunLoopObserver(id: UUID) {
        removedLateRunloopObserver = id
    }

    var finishedRunloopObserver: ((Sentry.RunLoopIteration) -> Void)?
    func addFinishedRunLoopObserver(handler: @escaping (Sentry.RunLoopIteration) -> Void) -> UUID {
        finishedRunloopObserver = handler
        return UUID()
    }
    
    var removedFinishedRunloopObserver: UUID?
    func removeFinishedRunLoopObserver(id: UUID) {
        removedFinishedRunloopObserver = id
    }
}

final class SentryWatchdogTerminationTrackingIntegrationSwiftTests: XCTestCase {
    
    func testReceivesHangStartedCallback() {
        let testHangTracker = TestHangTracker()
        let expectation = XCTestExpectation(description: "Expected to received a hang")
        let timeoutInterval = 1.0
        let sut = SentryWatchdogTerminationTrackingIntegrationSwift(
            hangTracker: testHangTracker,
            timeoutInterval: timeoutInterval) {
                expectation.fulfill()
        } hangStopped: {
                
        }

        sut.start()

        testHangTracker.lateRunloopObserver?(UUID(), timeoutInterval + 1)
        
        wait(for: [expectation], timeout: 10)
        
        sut.stop()
        
        XCTAssertNotNil(testHangTracker.removedLateRunloopObserver)
        XCTAssertNotNil(testHangTracker.removedFinishedRunloopObserver)
    }
    
    func testReceivesHangStoppedCallback() {
        let testHangTracker = TestHangTracker()
        let expectation = XCTestExpectation(description: "Expected to received hang stop")
        let timeoutInterval = 1.0
        let sut = SentryWatchdogTerminationTrackingIntegrationSwift(
            hangTracker: testHangTracker,
            timeoutInterval: timeoutInterval) {
        } hangStopped: {
                expectation.fulfill()
        }

        sut.start()

        testHangTracker.finishedRunloopObserver?(.init(startTime: 0, endTime: 0))
        
        wait(for: [expectation], timeout: 10)
        
        sut.stop()
        
        XCTAssertNotNil(testHangTracker.removedLateRunloopObserver)
        XCTAssertNotNil(testHangTracker.removedFinishedRunloopObserver)
    }
    
    func testDoesNotReceiveHangCallbackIfShorterThanTimeout() {
        let testHangTracker = TestHangTracker()
        let timeoutInterval = 1.0
        let sut = SentryWatchdogTerminationTrackingIntegrationSwift(
            hangTracker: testHangTracker,
            timeoutInterval: timeoutInterval) {
                XCTFail("Should not recieve the callback")
        } hangStopped: {
                
        }

        sut.start()

        testHangTracker.lateRunloopObserver?(UUID(), timeoutInterval - 1)
        
        sut.stop()
        
        XCTAssertNotNil(testHangTracker.removedLateRunloopObserver)
        XCTAssertNotNil(testHangTracker.removedFinishedRunloopObserver)
    }
    
}

#endif
