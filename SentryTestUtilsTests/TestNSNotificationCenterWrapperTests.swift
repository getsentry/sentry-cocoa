@testable import SentryTestUtils
import XCTest

class TestNSNotificationCenterWrapperTests: XCTestCase {

    private let notificationName = Notification.Name("TestNotification")
    private let dummySelector = #selector(dummyMethod)

    private var sut: TestNSNotificationCenterWrapper!

    override func setUp() {
        super.setUp()
        sut = TestNSNotificationCenterWrapper()
    }

    func testAddObserver_whenIgnoreAddObserverIsFalse_shouldRecordObserver() throws {
        // -- Arrange --
        sut.ignoreAddObserver = false

        // -- Act --
        sut.addObserver(self, selector: dummySelector, name: notificationName)

        // -- Assert --
        let invocations = sut.addObserverInvocations
        XCTAssertEqual(invocations.count, 1)
        let invocation = try XCTUnwrap(invocations.invocations.first)
        XCTAssertIdentical(invocation.observer.value, self)
        XCTAssertEqual(invocation.selector, dummySelector)
        XCTAssertEqual(invocation.name, notificationName)
    }

    func testAddObserver_whenIgnoreAddObserverIsTrue_shouldNotRecordObserver() {
        // -- Arrange --
        sut.ignoreAddObserver = true

        // -- Act --
        sut.addObserver(self, selector: dummySelector, name: notificationName)

        // -- Assert --
        XCTAssertEqual(sut.addObserverInvocations.count, 0)
    }

    func testAddObserverWithObject_whenIgnoreAddObserverIsFalse_shouldRecordObserver() throws {
        // -- Arrange --
        let object = "<some object>"
        sut.ignoreAddObserver = false

        // -- Act --
        sut.addObserver(self, selector: dummySelector, name: notificationName, object: object)

        // -- Assert --
        let invocations = sut.addObserverWithObjectInvocations
        XCTAssertEqual(invocations.count, 1)
        let invocation = try XCTUnwrap(invocations.first)
        XCTAssertIdentical(invocation.observer.value, self)
        XCTAssertEqual(invocation.selector, dummySelector)
        XCTAssertEqual(invocation.name, notificationName)
        XCTAssertEqual(invocation.object as? String, object)
    }

    func testAddObserverWithObject_whenIgnoreAddObserverIsTrue_shouldNotRecordObserver() {
        // -- Arrange --
        sut.ignoreAddObserver = true

        // -- Act --
        sut.addObserver(self, selector: dummySelector, name: notificationName)

        // -- Assert --
        XCTAssertEqual(sut.addObserverWithObjectInvocations.count, 0)
    }

    func testAddObserverWithBlock_shouldRecordBlockObserver() throws {
        // -- Arrange --
        sut.ignoreAddObserver = false
        let block: (Notification) -> Void = { _ in }

        // -- Act --
        let observer = sut.addObserver(forName: notificationName, object: nil, queue: nil, using: block)

        // -- Assert --
        XCTAssertNotNil(observer)

        XCTAssertEqual(sut.addObserverWithBlockInvocations.count, 1)
        let invocation = try XCTUnwrap(sut.addObserverWithBlockInvocations.invocations.first)
        XCTAssertEqual(invocation.name, notificationName)
        XCTAssertNotNil(invocation.block)
    }

    func testRemoveObserverWithName_shouldRecordRemoval() throws {
        // -- Act --
        sut.removeObserver(self, name: notificationName)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverWithNameInvocations.count, 1)
        let invocation = try XCTUnwrap(sut.removeObserverWithNameInvocations.invocations.first)
        XCTAssertEqual(invocation, notificationName)
    }

    func testRemoveObserver_whenIgnoreRemoveObserverIsFalse_shouldRecordRemoval() throws {
        // -- Arrange --
        sut.ignoreRemoveObserver = false

        // -- Act --
        sut.removeObserver(self)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverInvocations.count, 1)
    }

    func testRemoveObserver_whenIgnoreRemoveObserverIsTrue_shouldNotRecordRemoval() {
        // -- Arrange --
        sut.ignoreRemoveObserver = true

        // -- Act --
        sut.removeObserver(self)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverInvocations.count, 0)
    }

    func testPost_whenObserverAdded_shouldPerformSelectorOnObserverObject() {
        // -- Arrange --
        class Observer: NSObject {
            let invocations = Invocations<Notification?>()

            @objc func method(_ notification: Notification?) {
                invocations.record(notification)
            }
        }

        sut.ignoreAddObserver = false

        let observer = Observer()
        let object = NSObject()
        sut.addObserver(observer, selector: #selector(observer.method(_:)), name: notificationName, object: object)

        // -- Act --
        sut.post(Notification(name: notificationName, object: object))

        // -- Assert --
        XCTAssertEqual(observer.invocations.count, 1)
        let invocation = try? XCTUnwrap(observer.invocations.invocations.first)
        XCTAssertEqual(invocation?.name, notificationName)
        XCTAssertIdentical(invocation?.object as? NSObject, object)
    }

    // MARK: - Helpers

    @objc private func dummyMethod() {
        // Dummy selector for testing purposes
    }
}
