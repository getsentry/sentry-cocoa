@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

struct TestRunLoopObserver: RunLoopObserver { }

final class HangTrackerTests: XCTestCase {
    
    private var createdObservationBlock: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var observationBlock: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?
    private var testObserver = TestRunLoopObserver()
    private var calledRemoveObserver = false
    private var calledAddObserver = false
    private let queue = DispatchQueue(label: "io.sentry.test-queue")
    
    override func setUp() {
        super.setUp()
        observationBlock = nil
        calledRemoveObserver = false
        calledAddObserver = false
    }
    
    private func createObserver(_ allocator: CFAllocator?, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex, _ block: ((TestRunLoopObserver?, CFRunLoopActivity) -> Void)?) -> TestRunLoopObserver {
        createdObservationBlock = block
        return testObserver
    }
    
    private func addObserver(_ rl: CFRunLoop?, _ observer: TestRunLoopObserver?, _ mode: CFRunLoopMode?) {
        observationBlock = createdObservationBlock
        calledAddObserver = true
    }
    
    private func removeObserver(_ rl: CFRunLoop?, _ observer: TestRunLoopObserver?, _ mode: CFRunLoopMode?) {
        observationBlock = nil
        calledRemoveObserver = true
    }
  
  func testHangTrackerCallsRemoveObserverOnDealloc() {
      var sut: DefaultHangTracker? = DefaultHangTracker(
        dateProvider: TestCurrentDateProvider(),
        createObserver: createObserver,
        addObserver: addObserver,
        removeObserver: removeObserver,
        queue: queue)
    _ = sut?.addOngoingHangObserver(handler: { _, _ in })
      XCTAssertEqual(calledRemoveObserver, false)
      sut = nil
      XCTAssertEqual(calledRemoveObserver, true)
  }
    
    func testDoesNotCaptureHangsThatAreNotOngoing() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        
        var observedHang = false
        let id = sut.addOngoingHangObserver { _, _ in
            observedHang = true
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        // Ensure the queue does not run until after the full runloop
        queue.suspend()
        observationBlock?(testObserver, .afterWaiting)
        // 10s passed, this is a hang
        dateProvider.setSystemUptime(10)
        observationBlock?(testObserver, .beforeWaiting)
        
        // Start the queue again
        queue.resume()
        
        // This kind of hang is not caught, the hang observer is only called if
        // a hang was caught while it is *ongoing*. Sometimes we will only know
        // if a hang occurs after it's ended. It would be straightforward to add
        // support for that if we ever wanted it. But for now that API isn't needed.
        // It is best to keep that a separate API when we add it to make it clear which
        // thread the block gets called on.
        XCTAssertFalse(observedHang, "Should not observe hang")
        
        sut.removeObserver(id: id)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
    func testHangTrackerWhenNotHanging() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        
        var observedHang = false
        let id = sut.addOngoingHangObserver { _, _ in
            observedHang = true
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        // Ensure the queue does not run until after the full runloop
        queue.suspend()
        observationBlock?(testObserver, .afterWaiting)
        // 10 ms passed
        dateProvider.setSystemUptime(0.01)
        observationBlock?(testObserver, .beforeWaiting)
        
        // Start the queue again
        queue.resume()
        
        XCTAssertFalse(observedHang, "Should not observe hang")
        
        sut.removeObserver(id: id)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
    func testHangTrackerCallsLateRunLoop() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        
        var observerLastInterval: TimeInterval = 0
        var hangOngoing: Bool = false
        let expectation = XCTestExpectation()
        let id = sut.addOngoingHangObserver { interval, ongoing in
            observerLastInterval = interval
            hangOngoing = ongoing
            expectation.fulfill()
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        observationBlock?(testObserver, .afterWaiting)
        dateProvider.setSystemUptime(10)
                
        wait(for: [expectation])
        
        // Note: We are writing to these variables on a bg thread but reading them here
        // on the main thread. This is safe without any locks because in our test
        // environment we know that there will not be any more modifications
        XCTAssertEqual(10, observerLastInterval, "Expected hang interval to be 10")
        XCTAssertTrue(hangOngoing)
        
        observationBlock?(testObserver, .beforeWaiting)
        
        let expectation2 = XCTestExpectation()
        queue.async {
            expectation2.fulfill()
        }
        wait(for: [expectation2])
        XCTAssertFalse(hangOngoing)
        
        sut.removeObserver(id: id)

        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
    func testRemovesObserverDuringRunloop() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        
        let id = sut.addOngoingHangObserver { _, _ in }
        observationBlock?(testObserver, .afterWaiting)
        sut.removeObserver(id: id)
        
        XCTAssertTrue(calledRemoveObserver, "Expected runloop to not be observed after last observer is removed")
        // Ensure the background queue isn't stuck waiting for another runloop event
        let expectation = XCTestExpectation()
        queue.async {
            expectation.fulfill()
        }
        // Ensure the queue is not blocked
        wait(for: [expectation])
    }
    
    func testHangTrackerDeallocates() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        var sut: DefaultHangTracker? = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        weak let weakSut = sut
        
        _ = sut?.addOngoingHangObserver { _, _ in }
        observationBlock?(testObserver, .afterWaiting)
        observationBlock?(testObserver, .beforeWaiting)
        
        sut = nil
        
        XCTAssertNil(weakSut, "Expected observer to be deallocated")
    }
    
    /// Verifies that after one hang completes (ongoing=true then ongoing=false),
    /// a second hang is properly detected. This catches state-reset bugs with consecutive hangs.
    func testConsecutiveHangsAreDetected() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        
        var hangCount = 0
        var lastInterval: TimeInterval = 0
        var lastOngoing: Bool = false
        
        var hangCallback = XCTestExpectation()
        let id = sut.addOngoingHangObserver { interval, ongoing in
            lastInterval = interval
            lastOngoing = ongoing
            if !ongoing {
                hangCount += 1
            }
            hangCallback.fulfill()
        }
        
        // First hang: start
        observationBlock?(testObserver, .afterWaiting)
        dateProvider.setSystemUptime(10)
        wait(for: [hangCallback])
        
        XCTAssertEqual(lastInterval, 10, "First hang interval should be 10")
        XCTAssertTrue(lastOngoing, "First hang should be ongoing")
        
        // First hang: complete
        observationBlock?(testObserver, .beforeWaiting)
        
        let firstHangEndExpectation = XCTestExpectation(description: "First hang ended")
        queue.async {
            firstHangEndExpectation.fulfill()
        }
        wait(for: [firstHangEndExpectation])

        XCTAssertEqual(hangCount, 1, "First hang should be detected")
        XCTAssertFalse(lastOngoing, "First hang should no longer be ongoing")
        
        // Second hang: start (simulating another runloop iteration that hangs)
        dateProvider.setSystemUptime(20)
        observationBlock?(testObserver, .afterWaiting)
        dateProvider.setSystemUptime(35) // 15 second hang
        
        hangCallback = XCTestExpectation(description: "Second hang detected")
        wait(for: [hangCallback])

        XCTAssertEqual(lastInterval, 15, "Second hang interval should be 15")
        XCTAssertTrue(lastOngoing, "Second hang should be ongoing")
        
        // Second hang: complete
        observationBlock?(testObserver, .beforeWaiting)
        
        let secondHangEndExpectation = XCTestExpectation(description: "Second hang ended")
        queue.async {
            secondHangEndExpectation.fulfill()
        }
        wait(for: [secondHangEndExpectation])
        
        XCTAssertEqual(hangCount, 2, "Second hang should be detected after first hang completed")
        XCTAssertFalse(lastOngoing, "Second hang should no longer be ongoing")
        
        sut.removeObserver(id: id)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }

    func testMultipleObserversAllReceiveHangCallback() {
        let dateProvider = TestCurrentDateProvider()
        dateProvider.setSystemUptime(0)
        let sut = DefaultHangTracker(
            dateProvider: dateProvider,
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)

        var observer1Interval: TimeInterval = 0
        var observer1Ongoing: Bool = false
        var observer2Interval: TimeInterval = 0
        var observer2Ongoing: Bool = false
        var observer3Interval: TimeInterval = 0
        var observer3Ongoing: Bool = false

        let expectation1 = XCTestExpectation(description: "Observer 1 called")
        let expectation2 = XCTestExpectation(description: "Observer 2 called")
        let expectation3 = XCTestExpectation(description: "Observer 3 called")

        let id1 = sut.addOngoingHangObserver { interval, ongoing in
            observer1Interval = interval
            observer1Ongoing = ongoing
            expectation1.fulfill()
        }
        let id2 = sut.addOngoingHangObserver { interval, ongoing in
            observer2Interval = interval
            observer2Ongoing = ongoing
            expectation2.fulfill()
        }
        let id3 = sut.addOngoingHangObserver { interval, ongoing in
            observer3Interval = interval
            observer3Ongoing = ongoing
            expectation3.fulfill()
        }

        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")

        // Trigger a hang
        observationBlock?(testObserver, .afterWaiting)
        dateProvider.setSystemUptime(10)

        wait(for: [expectation1, expectation2, expectation3])

        // All observers should have received the hang with same interval
        XCTAssertEqual(observer1Interval, 10, "Observer 1 should receive hang interval")
        XCTAssertEqual(observer2Interval, 10, "Observer 2 should receive hang interval")
        XCTAssertEqual(observer3Interval, 10, "Observer 3 should receive hang interval")

        XCTAssertTrue(observer1Ongoing, "Observer 1 should report hang as ongoing")
        XCTAssertTrue(observer2Ongoing, "Observer 2 should report hang as ongoing")
        XCTAssertTrue(observer3Ongoing, "Observer 3 should report hang as ongoing")

        // End the hang
        observationBlock?(testObserver, .beforeWaiting)

        let hangEndExpectation = XCTestExpectation(description: "Hang ended")
        queue.async {
            hangEndExpectation.fulfill()
        }
        wait(for: [hangEndExpectation])

        // All observers should have been notified that the hang ended
        XCTAssertFalse(observer1Ongoing, "Observer 1 should report hang ended")
        XCTAssertFalse(observer2Ongoing, "Observer 2 should report hang ended")
        XCTAssertFalse(observer3Ongoing, "Observer 3 should report hang ended")

        sut.removeObserver(id: id1)
        sut.removeObserver(id: id2)
        sut.removeObserver(id: id3)
        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }

}
