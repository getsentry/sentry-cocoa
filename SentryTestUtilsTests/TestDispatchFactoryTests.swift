@testable import SentryTestUtils
import XCTest

/// This test suite is not intended to test the actual functionality of the dispatch factory,
/// but rather to ensure that the mock behaves correctly in a testing environment.
class TestDispatchFactoryTests: XCTestCase {

    class Fixture {
        let actualDispatchFactory = SentryDispatchFactory()
    }

    var sut: TestDispatchFactory!
    var fixture: Fixture!

    override func setUp() {
        super.setUp()

        sut = TestDispatchFactory()
        fixture = Fixture()
    }

    func testQueueWithNameAndAttributes_shouldReturnDispatchQueueWithGivenNameAndAttributes() {
        // Due to the absense of `dispatch_queue_attr_make_with_qos_class` in Swift, this method is not tested.
    }

    func testQueueWithNameAndAttributes_shouldCallVendedHandler() {
        // Due to the absense of `dispatch_queue_attr_make_with_qos_class` in Swift, this method is not tested.
    }

    func testCreateLowPriorityQueue_shouldReturnDispatchQueueWithLowPriority() {
        // -- Arrange --
        let queueName = "testLowPriorityQueue"
        let relativePriority: Int32 = -15

        let expectedQueueWrapper = TestSentryDispatchQueueWrapper(name: queueName, attributes: nil)

        // -- Act --
        let queueWrapper = sut.createLowPriorityQueue(queueName, relativePriority: relativePriority)

        // -- Assert --
        XCTAssertEqual(queueWrapper.queue.label, expectedQueueWrapper.queue.label)
        XCTAssertEqual(queueWrapper.queue.qos.qosClass, expectedQueueWrapper.queue.qos.qosClass)
        XCTAssertEqual(queueWrapper.queue.qos.relativePriority, expectedQueueWrapper.queue.qos.relativePriority)
    }

    func testCreateLowPriorityQueue_shouldRecordInvocation() throws {
        // -- Act --
        let _ = sut.createLowPriorityQueue("queue-1", relativePriority: -5)
        let _ = sut.createLowPriorityQueue("queue-2", relativePriority: -10)

        // -- Assert --
        XCTAssertEqual(sut.createLowPriorityQueueInvocations.count, 2)

        let firstInvocation = try XCTUnwrap(sut.createLowPriorityQueueInvocations.invocations.element(at: 0))
        XCTAssertEqual(firstInvocation.name, "queue-1")
        XCTAssertEqual(firstInvocation.relativePriority, -5)

        let secondInvocation = try XCTUnwrap(sut.createLowPriorityQueueInvocations.invocations.element(at: 1))
        XCTAssertEqual(secondInvocation.name, "queue-2")
        XCTAssertEqual(secondInvocation.relativePriority, -10)
    }

    func testSourceWithInterval_shouldReturnDispatchSourceWithGivenInterval() {
        // Due to the absense of `dispatch_queue_attr_make_with_qos_class` in Swift, this method is not tested.
    }

    func testSourceWithInterval_shouldCallVendedHandler() {
        // Due to the absense of `dispatch_queue_attr_make_with_qos_class` in Swift, this method is not tested.
    }
}
