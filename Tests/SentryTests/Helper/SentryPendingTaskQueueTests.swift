@testable import Sentry
import XCTest

class SentryPendingTaskQueueTests: XCTestCase {

    private var sut: SentryPendingTaskQueue!

    override func setUp() {
        super.setUp()
        sut = SentryDependencyContainer.sharedInstance().pendingTaskQueue
        sut.clearPendingTasks()
    }

    override func tearDown() {
        sut.clearPendingTasks()
        super.tearDown()
    }

    func testEnqueue_whenCalled_shouldIncreasePendingTaskCount() {
        // -- Arrange --
        XCTAssertEqual(0, sut.pendingTaskCount)

        // -- Act --
        sut.enqueue { }

        // -- Assert --
        XCTAssertEqual(1, sut.pendingTaskCount)
    }

    func testEnqueue_whenCalledMultipleTimes_shouldAccumulateTasks() {
        // -- Arrange --
        XCTAssertEqual(0, sut.pendingTaskCount)

        // -- Act --
        sut.enqueue { }
        sut.enqueue { }
        sut.enqueue { }

        // -- Assert --
        XCTAssertEqual(3, sut.pendingTaskCount)
    }

    func testExecutePendingTasks_whenTasksExist_shouldExecuteAllTasksInOrder() {
        // -- Arrange --
        var executionOrder: [Int] = []

        sut.enqueue { executionOrder.append(1) }
        sut.enqueue { executionOrder.append(2) }
        sut.enqueue { executionOrder.append(3) }

        // -- Act --
        sut.executePendingTasks()

        // -- Assert --
        XCTAssertEqual([1, 2, 3], executionOrder)
        XCTAssertEqual(0, sut.pendingTaskCount)
    }

    func testExecutePendingTasks_whenNoTasks_shouldDoNothing() {
        // -- Arrange --
        XCTAssertEqual(0, sut.pendingTaskCount)

        // -- Act --
        sut.executePendingTasks()

        // -- Assert --
        XCTAssertEqual(0, sut.pendingTaskCount)
    }

    func testClearPendingTasks_whenTasksExist_shouldRemoveAllWithoutExecuting() {
        // -- Arrange --
        var wasExecuted = false
        sut.enqueue { wasExecuted = true }
        XCTAssertEqual(1, sut.pendingTaskCount)

        // -- Act --
        sut.clearPendingTasks()

        // -- Assert --
        XCTAssertEqual(0, sut.pendingTaskCount)
        XCTAssertFalse(wasExecuted)
    }

    func testExecutePendingTasks_whenCalledTwice_shouldOnlyExecuteOnce() {
        // -- Arrange --
        var executionCount = 0
        sut.enqueue { executionCount += 1 }

        // -- Act --
        sut.executePendingTasks()
        sut.executePendingTasks()

        // -- Assert --
        XCTAssertEqual(1, executionCount)
    }

    func testEnqueueAndExecute_whenConcurrent_shouldBeThreadSafe() {
        // -- Arrange --
        let queue1 = DispatchQueue(label: "test.queue1", attributes: .concurrent)
        let queue2 = DispatchQueue(label: "test.queue2", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "All tasks completed")
        expectation.expectedFulfillmentCount = 100

        var executionCount = 0
        let lock = NSLock()

        // -- Act --
        for _ in 0..<50 {
            queue1.async {
                self.sut.enqueue {
                    lock.withLock {
                        executionCount += 1
                    }
                }
                expectation.fulfill()
            }

            queue2.async {
                self.sut.enqueue {
                    lock.withLock {
                        executionCount += 1
                    }
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Execute all pending tasks
        sut.executePendingTasks()

        // -- Assert --
        XCTAssertEqual(100, executionCount)
        XCTAssertEqual(0, sut.pendingTaskCount)
    }
}
