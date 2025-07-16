// swiftlint:disable file_length type_body_length

@testable import SentryTestUtils
import XCTest

class TestNSNotificationCenterWrapperTests: XCTestCase {

    private let notificationName = Notification.Name("TestNotification")
    private let otherNotificationName = Notification.Name("OtherNotification")
    private let dummySelector = #selector(dummyMethod)
    private let keyPath = "testKeyPath"

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
        let invocations = sut.addObserverWithObjectInvocations
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
        XCTAssertEqual(sut.addObserverWithObjectInvocations.count, 0)
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
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 1)
        let invocation = try XCTUnwrap(sut.removeObserverWithNameAndObjectInvocations.invocations.first)
        XCTAssertEqual(invocation.name, notificationName)
    }

    func testRemoveObserver_whenIgnoreRemoveObserverIsFalse_shouldRecordRemoval() throws {
        // -- Arrange --
        sut.ignoreRemoveObserver = false

        // -- Act --
        sut.removeObserver(self)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 1)
    }

    func testRemoveObserver_whenIgnoreRemoveObserverIsTrue_shouldNotRecordRemoval() {
        // -- Arrange --
        sut.ignoreRemoveObserver = true

        // -- Act --
        sut.removeObserver(self)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 0)
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

    // MARK: - KVO Observer Tests

    func testAddObserverForKeyPath_whenIgnoreAddObserverIsFalse_shouldRecordObserver() throws {
        // -- Arrange --
        sut.ignoreAddObserver = false
        let options: NSKeyValueObservingOptions = [.new, .old]
        let context = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        defer { context.deallocate() }

        // -- Act --
        sut.addObserver(self, forKeyPath: keyPath, options: options, context: context)

        // -- Assert --
        let invocations = sut.addObserverForKeyPathWithContextInvocations
        XCTAssertEqual(invocations.count, 1)
        let invocation = try XCTUnwrap(invocations.invocations.first)
        XCTAssertIdentical(invocation.observer.value, self)
        XCTAssertEqual(invocation.keyPath, keyPath)
        XCTAssertEqual(invocation.options, options)
        XCTAssertEqual(invocation.context, context)
    }

    func testAddObserverForKeyPath_whenIgnoreAddObserverIsTrue_shouldNotRecordObserver() {
        // -- Arrange --
        sut.ignoreAddObserver = true

        // -- Act --
        sut.addObserver(self, forKeyPath: keyPath, options: [], context: nil)

        // -- Assert --
        XCTAssertEqual(sut.addObserverForKeyPathWithContextInvocations.count, 0)
    }

    func testRemoveObserverForKeyPath_whenIgnoreRemoveObserverIsFalse_shouldRecordRemoval() throws {
        // -- Arrange --
        sut.ignoreRemoveObserver = false

        // -- Act --
        sut.removeObserver(self, forKeyPath: keyPath)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverForKeyPathWithContextInvocations.count, 1)
        let invocation = try XCTUnwrap(sut.removeObserverForKeyPathWithContextInvocations.invocations.first)
        XCTAssertEqual(invocation.keyPath, keyPath)
    }

    func testRemoveObserverForKeyPath_whenIgnoreRemoveObserverIsTrue_shouldNotRecordRemoval() {
        // -- Arrange --
        sut.ignoreRemoveObserver = true

        // -- Act --
        sut.removeObserver(self, forKeyPath: keyPath)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverForKeyPathWithContextInvocations.count, 0)
    }

    func testRemoveObserverForKeyPathWithContext_whenIgnoreRemoveObserverIsFalse_shouldRecordRemoval() throws {
        // -- Arrange --
        sut.ignoreRemoveObserver = false
        let context = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        defer { context.deallocate() }

        // -- Act --
        sut.removeObserver(self, forKeyPath: keyPath, context: context)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverForKeyPathWithContextInvocations.count, 1)
        let invocation = try XCTUnwrap(sut.removeObserverForKeyPathWithContextInvocations.invocations.first)
        XCTAssertEqual(invocation.keyPath, keyPath)
        XCTAssertEqual(invocation.context, context)
    }

    func testRemoveObserverWithNameAndObject_shouldRecordRemoval() throws {
        // -- Arrange --
        let object = NSObject()

        // -- Act --
        sut.removeObserver(self, name: notificationName, object: object)

        // -- Assert --
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 1)
        let invocation = try XCTUnwrap(sut.removeObserverWithNameAndObjectInvocations.invocations.first)
        XCTAssertEqual(invocation.name, notificationName)
        XCTAssertIdentical(invocation.object as? NSObject, object)
    }

    // MARK: - Observer Lifecycle Tests

    func testRemoveObserver_shouldActuallyRemoveObserverFromArray() {
        // -- Arrange --
        sut.ignoreAddObserver = false
        sut.ignoreRemoveObserver = false
        sut.addObserver(self, selector: dummySelector, name: notificationName)
        XCTAssertEqual(sut.observerCount, 1)

        // -- Act --
        sut.removeObserver(self)

        // -- Assert --
        XCTAssertEqual(sut.observerCount, 0)
    }

    func testRemoveObserverWithName_shouldActuallyRemoveObserverFromArray() {
        // -- Arrange --
        sut.ignoreAddObserver = false
        sut.ignoreRemoveObserver = false
        sut.addObserver(self, selector: dummySelector, name: notificationName)
        XCTAssertEqual(sut.observerCount, 1)

        // -- Act --
        sut.removeObserver(self, name: notificationName)

        // -- Assert --
        XCTAssertEqual(sut.observerCount, 0)
    }

    func testRemoveObserverForKeyPath_shouldActuallyRemoveObserverFromArray() {
        // -- Arrange --
        sut.ignoreAddObserver = false
        sut.ignoreRemoveObserver = false
        sut.addObserver(self, forKeyPath: keyPath, options: [], context: nil)
        XCTAssertEqual(sut.observerCount, 1)

        // -- Act --
        sut.removeObserver(self, forKeyPath: keyPath)

        // -- Assert --
        XCTAssertEqual(sut.observerCount, 0)
    }

    // MARK: - Post Method Tests

    func testPost_withSimpleObserver_shouldCallSelector() {
        // -- Arrange --
        class Observer: NSObject {
            var called = false
            @objc func testMethod(_ notification: Notification) {
                called = true
            }
        }

        let observer = Observer()
        sut.addObserver(observer, selector: #selector(observer.testMethod(_:)), name: notificationName)

        // -- Act --
        sut.post(Notification(name: notificationName))

        // -- Assert --
        XCTAssertTrue(observer.called)
    }

    func testPost_withWrongNotificationName_shouldNotCallSelector() {
        // -- Arrange --
        class Observer: NSObject {
            var called = false
            @objc func testMethod(_ notification: Notification) {
                called = true
            }
        }

        let observer = Observer()
        sut.addObserver(observer, selector: #selector(observer.testMethod(_:)), name: notificationName)

        // -- Act --
        sut.post(Notification(name: otherNotificationName))

        // -- Assert --
        XCTAssertFalse(observer.called)
    }

    func testPost_withObjectFilteredObserver_matchingObject_shouldCallSelector() {
        // -- Arrange --
        class Observer: NSObject {
            var called = false
            @objc func testMethod(_ notification: Notification) {
                called = true
            }
        }

        let observer = Observer()
        let object = NSObject()
        sut.addObserver(observer, selector: #selector(observer.testMethod(_:)), name: notificationName, object: object)

        // -- Act --
        sut.post(Notification(name: notificationName, object: object))

        // -- Assert --
        XCTAssertTrue(observer.called)
    }

    func testPost_withObjectFilteredObserver_nonMatchingObject_shouldNotCallSelector() {
        // -- Arrange --
        class Observer: NSObject {
            var called = false
            @objc func testMethod(_ notification: Notification) {
                called = true
            }
        }

        let observer = Observer()
        let filterObject = NSObject()
        let postObject = NSObject()
        sut.addObserver(observer, selector: #selector(observer.testMethod(_:)), name: notificationName, object: filterObject)

        // -- Act --
        sut.post(Notification(name: notificationName, object: postObject))

        // -- Assert --
        XCTAssertFalse(observer.called)
    }

    func testPost_withObjectFilteredObserver_nilObjects_shouldCallSelector() {
        // -- Arrange --
        class Observer: NSObject {
            var called = false
            @objc func testMethod(_ notification: Notification) {
                called = true
            }
        }

        let observer = Observer()
        sut.addObserver(observer, selector: #selector(observer.testMethod(_:)), name: notificationName, object: nil)

        // -- Act --
        sut.post(Notification(name: notificationName, object: nil))

        // -- Assert --
        XCTAssertTrue(observer.called)
    }

    func testPost_withBlockObserver_matchingName_shouldCallBlock() {
        // -- Arrange --
        var blockCalled = false
        let block: (Notification) -> Void = { _ in blockCalled = true }
        
        _ = sut.addObserver(forName: notificationName, object: nil, queue: nil, using: block)

        // -- Act --
        sut.post(Notification(name: notificationName))

        // -- Assert --
        XCTAssertTrue(blockCalled)
    }

    func testPost_withBlockObserver_nilName_shouldCallBlockForAnyNotification() {
        // -- Arrange --
        var blockCalled = false
        let block: (Notification) -> Void = { _ in blockCalled = true }
        
        _ = sut.addObserver(forName: nil, object: nil, queue: nil, using: block)

        // -- Act --
        sut.post(Notification(name: notificationName))

        // -- Assert --
        XCTAssertTrue(blockCalled)
    }

    func testPost_withBlockObserver_wrongName_shouldNotCallBlock() {
        // -- Arrange --
        var blockCalled = false
        let block: (Notification) -> Void = { _ in blockCalled = true }
        
        _ = sut.addObserver(forName: notificationName, object: nil, queue: nil, using: block)

        // -- Act --
        sut.post(Notification(name: otherNotificationName))

        // -- Assert --
        XCTAssertFalse(blockCalled)
    }

    func testPost_withMultipleObservers_shouldCallAllMatchingObservers() {
        // -- Arrange --
        class Observer: NSObject {
            var callCount = 0
            @objc func testMethod(_ notification: Notification) {
                callCount += 1
            }
        }

        let observer1 = Observer()
        let observer2 = Observer()
        let observer3 = Observer()
        
        sut.addObserver(observer1, selector: #selector(observer1.testMethod(_:)), name: notificationName)
        sut.addObserver(observer2, selector: #selector(observer2.testMethod(_:)), name: notificationName)
        sut.addObserver(observer3, selector: #selector(observer3.testMethod(_:)), name: otherNotificationName)

        // -- Act --
        sut.post(Notification(name: notificationName))

        // -- Assert --
        XCTAssertEqual(observer1.callCount, 1)
        XCTAssertEqual(observer2.callCount, 1)
        XCTAssertEqual(observer3.callCount, 0) // Different notification name
    }

    func testPost_withKVOObserver_shouldNotCallObserver() {
        // -- Arrange --
        class Observer: NSObject {
            var called = false
            override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
                called = true
            }
        }

        let observer = Observer()
        sut.addObserver(observer, forKeyPath: keyPath, options: [], context: nil)

        // -- Act --
        sut.post(Notification(name: notificationName))

        // -- Assert --
        XCTAssertFalse(observer.called) // KVO observers shouldn't respond to regular notifications
    }

    // MARK: - Edge Cases

    func testObserverCount_initiallyZero() {
        XCTAssertEqual(sut.observerCount, 0)
    }

    func testObserverCount_afterAddingObservers() {
        sut.addObserver(self, selector: dummySelector, name: notificationName)
        sut.addObserver(self, selector: dummySelector, name: otherNotificationName)
        sut.addObserver(self, forKeyPath: keyPath, options: [], context: nil)
        
        XCTAssertEqual(sut.observerCount, 3)
    }

    func testClearAllObservers_shouldRemoveAllObserversAndInvocations() {
        // -- Arrange --
        sut.addObserver(self, selector: dummySelector, name: notificationName)
        sut.addObserver(self, selector: dummySelector, name: notificationName, object: nil)
        sut.addObserver(self, forKeyPath: keyPath, options: [], context: nil)
        
        // Add some remove invocations too
        let dummyObserver = NSObject()
        sut.removeObserver(dummyObserver)
        
        // Verify we have observers and invocations before clearing
        XCTAssertEqual(sut.observerCount, 3)
        XCTAssertEqual(sut.addObserverWithObjectInvocations.count, 2)
        XCTAssertEqual(sut.addObserverForKeyPathWithContextInvocations.count, 1)
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 1)

        // -- Act --
        sut.clearAllObservers()

        // -- Assert --
        XCTAssertEqual(sut.observerCount, 0)
        XCTAssertEqual(sut.addObserverWithObjectInvocations.count, 0)
        XCTAssertEqual(sut.addObserverWithObjectInvocations.count, 0)
        XCTAssertEqual(sut.addObserverForKeyPathWithContextInvocations.count, 0)
        XCTAssertEqual(sut.addObserverWithBlockInvocations.count, 0)
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 0)
    }

    func testIgnoreFlags_whenSet_shouldPreventOperations() {
        // -- Arrange --
        sut.ignoreAddObserver = true
        sut.ignoreRemoveObserver = true

        // -- Act --
        sut.addObserver(self, selector: dummySelector, name: notificationName)
        sut.removeObserver(self)

        // -- Assert --
        XCTAssertEqual(sut.observerCount, 0)
        XCTAssertEqual(sut.addObserverWithObjectInvocations.count, 0)
        XCTAssertEqual(sut.removeObserverWithNameAndObjectInvocations.count, 0)
    }

    // MARK: - Helpers

    @objc private func dummyMethod() {
        // Dummy selector for testing purposes
    }
}

// swiftlint:enable file_length type_body_length
