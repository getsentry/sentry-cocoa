@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

struct TestRunLoopObserver: RunLoopObserver { }

final class HangTrackerTests: XCTestCase {
    
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
        observationBlock = block
        return testObserver
    }
    
    private func addObserver(_ rl: CFRunLoop?, _ observer: TestRunLoopObserver?, _ mode: CFRunLoopMode?) {
        calledAddObserver = true
    }
    
    private func removeObserver(_ rl: CFRunLoop?, _ observer: TestRunLoopObserver?, _ mode: CFRunLoopMode?) {
        calledRemoveObserver = true
    }
    
    func testHangTrackerCallsFinished() {
        let sut = DefaultHangTracker(
            dateProvider: TestCurrentDateProvider(),
            createObserver: createObserver,
            addObserver: addObserver,
            removeObserver: removeObserver,
            queue: queue)
        
        var observerCalls = 0
        let id = sut.addFinishedRunLoopObserver { _ in
            observerCalls += 1
        }
        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        observationBlock?(testObserver, .afterWaiting)
        observationBlock?(testObserver, .beforeWaiting)
        XCTAssertEqual(1, observerCalls, "Expected run loop to finish exactly once")
        sut.removeFinishedRunLoopObserver(id: id)
        
        // Observers are removed after the bg thread runs
        let expectation = XCTestExpectation()
        queue.async {
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        wait(for: [expectation])

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
        
        var observerIds = Set<UUID>()
        var observerLastInterval: TimeInterval = 0
        let id = sut.addLateRunLoopObserver { id, interval in
            observerIds.insert(id)
            observerLastInterval = interval
        }
        var expectation = XCTestExpectation()
        queue.async {
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        wait(for: [expectation])

        XCTAssertTrue(calledAddObserver, "Expected add observer to be called")
        
        observationBlock?(testObserver, .afterWaiting)
        dateProvider.setSystemUptime(10)
        // Wait 1 second for the hang detection to kick in
        sleep(1)
        observationBlock?(testObserver, .beforeWaiting)
        
        sut.removeLateRunLoopObserver(id: id)
        
        // Observers are removed after the bg thread runs
        expectation = XCTestExpectation()
        queue.async {
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
        
        // Note: We are writing to these variables on a bg thread but reading them here
        // on the main thread. This is safe without any locks because in our test
        // environment we know that once queue is drained there will not be any more modifictions
        XCTAssertEqual(1, observerIds.count, "Expected late run loop exactly once")
        XCTAssertEqual(10, observerLastInterval, "Expected hang interval to be 10")

        XCTAssertTrue(calledRemoveObserver, "Expected observer to be removed")
    }
    
}
