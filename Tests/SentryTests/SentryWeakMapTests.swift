@testable import Sentry
import XCTest

class SentryWeakMapTests: XCTestCase {

    // The weak map is used to store weak references to objects.
    // These classes are used as keys and values in the weak map.
    // Any other class could be used as well, these are added for simplicity.

    private class TestKey {}
    private class TestValue {}

    func testObjectForKey_keyIsNil_shouldReturnNil() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key: TestKey? = nil

        // -- Act --
        let result = map.object(forKey: key)

        // -- Assert --
        XCTAssertNil(result)
    }

    func testObjectForKey_nonNilKeyIsNotFound_shouldReturnNil() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key = TestKey()

        // -- Act --
        let result = map.object(forKey: key)

        // -- Assert --
        XCTAssertNil(result)
    }

    func testObjectForKey_keyIsFound_shouldReturnValue() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key = TestKey()
        let value = TestValue()
        map.setObject(value, forKey: key)

        // -- Act --
        let result = map.object(forKey: key)

        // -- Assert --
        XCTAssertTrue(result === value)
    }

    func testObjectForKey_shouldPruneWeakReferences() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var key1: TestKey? = TestKey()
        let value1 = TestValue()
        map.setObject(value1, forKey: key1)

        let key2 = TestKey()
        let value2 = TestValue()
        map.setObject(value2, forKey: key2)

        // Deallocate key1, which should remove the weak reference to value1
        key1 = nil

        // -- Act --
        let sizeBeforePrune = map.count()
        let result = map.object(forKey: key2)
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertTrue(result === value2)
        XCTAssertEqual(sizeBeforePrune, 2)
        XCTAssertEqual(sizeAfterPrune, 1)
    }

    func testSetObject_keyIsNilAndValueIsNil_shouldNotAddObject() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key: TestKey? = nil
        let value: TestValue? = nil

        // -- Act --
        map.setObject(value, forKey: key)

        // -- Assert --
        XCTAssertEqual(map.count(), 0)
    }

    func testSetObject_keyIsNilAndValueIsNotNil_shouldNotAddObject() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key: TestKey? = nil
        let value = TestValue()

        // -- Act --
        map.setObject(value, forKey: key)

        // -- Assert --
        XCTAssertEqual(map.count(), 0)
        XCTAssertNil(map.object(forKey: key))
    }

    func testSetObject_keyIsNotNilAndValueIsNil_shouldNotAddObject() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key = TestKey()
        let value: TestValue? = nil

        // -- Act --
        map.setObject(value, forKey: key)

        // -- Assert --
        XCTAssertEqual(map.count(), 0)
        XCTAssertNil(map.object(forKey: key))
    }

    func testSetObject_keyIsNotNilAndValueIsNotNil_shouldAddObject() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key = TestKey()
        let value = TestValue()

        // -- Act --
        map.setObject(value, forKey: key)

        // -- Assert --
        XCTAssertEqual(map.count(), 1)
        XCTAssertTrue(map.object(forKey: key) === value)
    }

    func testSetObject_shouldPruneWeakReferences() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var key1: TestKey? = TestKey()
        let value1 = TestValue()
        map.setObject(value1, forKey: key1)

        let key2 = TestKey()
        let value2A = TestValue()
        let value2B = TestValue()
        map.setObject(value2A, forKey: key2)

        // Deallocate key1, which should remove the weak reference to value1
        key1 = nil
        let sizeBeforePrune = map.count()

        // -- Act --
        map.setObject(value2B, forKey: key2)
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertEqual(sizeBeforePrune, 2)
        XCTAssertEqual(sizeAfterPrune, 1)
    }

    func testRemoveObjectForKey_keyIsNil_shouldNotRemoveObject() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key: TestKey? = nil
        let value = TestValue()
        map.setObject(value, forKey: key)

        // -- Act --
        map.removeObject(forKey: key)

        // -- Assert --
        XCTAssertEqual(map.count(), 0)
    }

    func testRemoveObjectForKey_keyIsNotNil_shouldRemoveObject() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key = TestKey()
        let value = TestValue()
        map.setObject(value, forKey: key)

        // -- Act --
        map.removeObject(forKey: key)

        // -- Assert --
        XCTAssertEqual(map.count(), 0)
        XCTAssertNil(map.object(forKey: key))
    }

    func testRemoveObjectForKey_shouldPruneWeakReferences() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var key1: TestKey? = TestKey()
        let value1 = TestValue()
        map.setObject(value1, forKey: key1)

        let key2 = TestKey()
        let value2 = TestValue()
        map.setObject(value2, forKey: key2)

        // Deallocate key1, which should remove the weak reference to value1
        key1 = nil
        let sizeBeforePrune = map.count()

        // -- Act --
        map.removeObject(forKey: key2)
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertEqual(sizeBeforePrune, 2)
        // Key1 was deallocated, and key2 was removed, so the map should be empty
        XCTAssertEqual(sizeAfterPrune, 0)
    }

    func testCount_shouldReturnZeroWhenEmpty() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()

        // -- Act --
        let count = map.count()

        // -- Assert --
        XCTAssertEqual(count, 0)
    }

    func testCount_shouldReturnCorrectCount() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let key1 = TestKey()
        let value1 = TestValue()
        map.setObject(value1, forKey: key1)

        let key2 = TestKey()
        let value2 = TestValue()
        map.setObject(value2, forKey: key2)

        // -- Act --
        let count = map.count()

        // -- Assert --
        XCTAssertEqual(count, 2)
    }

    func testPrune_emptyMap_shouldNotCrash() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()

        // -- Act --
        let sizeBeforePrune = map.count()
        map.prune()
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertEqual(sizeBeforePrune, 0)
        // The map is empty, so the prune operation should not change the count
        XCTAssertEqual(sizeAfterPrune, 0)
    }

    func testPrune_referenceNotDeallocated_shouldNotRemoveAnyObjects() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let keys = (0..<100).map { _ in TestKey() }
        let values = (0..<100).map { _ in TestValue() }
        for (key, value) in zip(keys, values) {
            map.setObject(value, forKey: key)
        }

        // -- Act --
        let sizeBeforePrune = map.count()
        map.prune()
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertEqual(sizeBeforePrune, 100)
        // No keys were deallocated, so the map should have 100 objects remaining
        XCTAssertEqual(sizeAfterPrune, 100)
    }

    func testPrune_referencesPartiallyDeallocated_shouldPartiallyRemoveObjects() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var keys = (0..<100).map { _ in TestKey() }
        for key in keys {
            map.setObject(TestValue(), forKey: key)
        }

        // -- Act --
        // Partially deallocate some keys
        keys.removeFirst(30)

        let sizeBeforePrune = map.count()
        map.prune()
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertEqual(sizeBeforePrune, 100)
        // 30 keys were deallocated, so the map should have 70 objects remaining
        XCTAssertEqual(sizeAfterPrune, 70)
    }

    func testPrune_referencesAllDeallocated_shouldRemoveAllObjects() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var keys = (0..<100).map { _ in TestKey() }
        for key in keys {
            map.setObject(TestValue(), forKey: key)
        }

        // -- Act --
        // Deallocate all keys
        keys = []

        let sizeBeforePrune = map.count()
        map.prune()
        let sizeAfterPrune = map.count()

        // -- Assert --
        XCTAssertEqual(sizeBeforePrune, 100)
        // All keys were deallocated, so the map should be empty
        XCTAssertEqual(sizeAfterPrune, 0)
    }
}
