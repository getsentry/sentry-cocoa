@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
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

    func testCreateUtilityQueue_shouldReturnDispatchQueueWithLowPriority() {
        // -- Arrange --
        let queueName = "testUtilityQueue"
        let relativePriority: Int32 = -15

        let expectedQueueWrapper = TestSentryDispatchQueueWrapper(name: queueName, attributes: nil)

        // -- Act --
        let queueWrapper = sut.createUtilityQueue(queueName, relativePriority: relativePriority)

        // -- Assert --
        XCTAssertEqual(queueWrapper.queue.label, expectedQueueWrapper.queue.label)
        XCTAssertEqual(queueWrapper.queue.qos.qosClass, expectedQueueWrapper.queue.qos.qosClass)
        XCTAssertEqual(queueWrapper.queue.qos.relativePriority, expectedQueueWrapper.queue.qos.relativePriority)
    }

    func testCreateUtilityQueue_shouldRecordInvocation() throws {
        // -- Act --
        let _ = sut.createUtilityQueue("queue-1", relativePriority: -5)
        let _ = sut.createUtilityQueue("queue-2", relativePriority: -10)

        // -- Assert --
        XCTAssertEqual(sut.createUtilityQueueInvocations.count, 2)

        let firstInvocation = try XCTUnwrap(sut.createUtilityQueueInvocations.invocations.element(at: 0))
        XCTAssertEqual(firstInvocation.name, "queue-1")
        XCTAssertEqual(firstInvocation.relativePriority, -5)

        let secondInvocation = try XCTUnwrap(sut.createUtilityQueueInvocations.invocations.element(at: 1))
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
