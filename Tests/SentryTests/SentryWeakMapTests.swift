#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#else
@testable import Sentry
#endif
import SentryTestUtilsObjC
import XCTest

class SentryWeakMapTests: XCTestCase {

    // The weak map is used to store weak references to objects.
    // These classes are used as keys and values in the weak map.
    // Any other class could be used as well, these are added for simplicity.

    private class TestKey {}
    private class TestValue {}

    private class EqualKey: NSObject {
        override var hash: Int { 1 }

        override func isEqual(_ object: Any?) -> Bool {
            object is EqualKey
        }
    }

    private class CollidingKey: NSObject {
        override var hash: Int { 1 }
    }

    private class PruningWorkMap: SentryWeakMap<TestKey, TestValue> {
        var entriesVisited = 0

        override func prune() {
            entriesVisited += Int(count())
            super.prune()
        }
    }

    func testAccess_whenManyKeysStayAlive_shouldKeepPruningWorkLinear() {
        // -- Arrange --
        let map = PruningWorkMap()
        let keys = (0..<5_000).map { _ in TestKey() }
        let value = TestValue()

        // -- Act --
        withExtendedLifetime(keys) {
            for key in keys {
                map.setObject(value, forKey: key)
            }
            for key in keys {
                XCTAssertTrue(map.object(forKey: key) === value)
            }
            for key in keys {
                map.removeObject(forKey: key)
            }
        }

        // -- Assert --
        // Count entries scanned rather than wall time so this catches quadratic pruning on any host.
        XCTAssertLessThanOrEqual(map.entriesVisited, keys.count * 8)
        XCTAssertEqual(map.count(), 0)
    }

    func testAccess_whenKeysAreDeallocated_shouldBoundCleanupPerAccess() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var keys = (0..<1_000).map { _ in TestKey() }
        let liveKey = keys[999]
        let value = TestValue()
        for key in keys {
            map.setObject(value, forKey: key)
        }
        keys.removeAll()
        var largestCleanup = 0

        // -- Act --
        for _ in 0..<1_000 {
            let countBefore = map.count()
            XCTAssertTrue(map.object(forKey: liveKey) === value)
            largestCleanup = max(largestCleanup, Int(countBefore - map.count()))
        }

        // -- Assert --
        XCTAssertLessThanOrEqual(largestCleanup, 2)
        XCTAssertEqual(map.count(), 1)
    }

    func testAccess_whenManyKeysStayAlive_shouldMeasureBulkOperations() {
        // -- Arrange --
        let keys = (0..<5_000).map { _ in TestKey() }
        let value = TestValue()

        // -- Act --
        measure {
            let map = SentryWeakMap<TestKey, TestValue>()
            for key in keys {
                map.setObject(value, forKey: key)
            }
            for key in keys {
                XCTAssertTrue(map.object(forKey: key) === value)
            }
            for key in keys {
                map.removeObject(forKey: key)
            }

            // -- Assert --
            XCTAssertEqual(map.count(), 0)
        }
        withExtendedLifetime(keys) {}
    }

    func testPrune_whenKeyIsDeallocated_shouldReleaseValueImmediately() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let liveKey = TestKey()
        let liveValue = TestValue()
        map.setObject(liveValue, forKey: liveKey)
        weak var releasedValue: TestValue?
        autoreleasepool {
            let key = TestKey()
            let value = TestValue()
            releasedValue = value
            map.setObject(value, forKey: key)
        }

        XCTAssertEqual(map.count(), 2)
        XCTAssertNotNil(releasedValue)

        // -- Act --
        map.prune()

        // -- Assert --
        XCTAssertEqual(map.count(), 1)
        XCTAssertNil(releasedValue)
        XCTAssertTrue(map.object(forKey: liveKey) === liveValue)
    }

    func testSetObject_whenKeysAreEqual_shouldReplaceExistingEntry() {
        // -- Arrange --
        let map = SentryWeakMap<EqualKey, TestValue>()
        let firstKey = EqualKey()
        let equalKey = EqualKey()
        let firstValue = TestValue()
        let replacementValue = TestValue()
        map.setObject(firstValue, forKey: firstKey)

        // -- Act --
        map.setObject(replacementValue, forKey: equalKey)

        // -- Assert --
        withExtendedLifetime((firstKey, equalKey)) {
            XCTAssertEqual(map.count(), 1)
            XCTAssertTrue(map.object(forKey: firstKey) === replacementValue)
            XCTAssertTrue(map.object(forKey: equalKey) === replacementValue)
            map.removeObject(forKey: equalKey)
            XCTAssertEqual(map.count(), 0)
        }
    }

    func testPrune_whenDeadKeysHaveCollidingHashes_shouldPreserveLiveEntry() {
        // -- Arrange --
        let map = SentryWeakMap<CollidingKey, TestValue>()
        var keys = (0..<100).map { _ in CollidingKey() }
        let liveKey = keys[50]
        let value = TestValue()
        for key in keys {
            map.setObject(value, forKey: key)
        }
        keys.removeAll()

        // -- Act --
        map.prune()

        // -- Assert --
        XCTAssertEqual(map.count(), 1)
        XCTAssertTrue(map.object(forKey: liveKey) === value)
    }

    func testRemoveObjectForKey_whenHeadMiddleAndTailAreRemoved_shouldKeepCleanupWorking() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var keys = (0..<100).map { _ in TestKey() }
        let value = TestValue()
        for key in keys {
            map.setObject(value, forKey: key)
        }

        // -- Act --
        for index in [0, 50, 99] {
            map.removeObject(forKey: keys[index])
            XCTAssertNil(map.object(forKey: keys[index]))
        }
        let countAfterRemoval = map.count()
        keys.removeAll()
        map.prune()

        // -- Assert --
        XCTAssertEqual(countAfterRemoval, 97)
        XCTAssertEqual(map.count(), 0)
        let newKey = TestKey()
        map.setObject(value, forKey: newKey)
        XCTAssertTrue(map.object(forKey: newKey) === value)
        XCTAssertEqual(map.count(), 1)
    }

    func testPrune_whenCursorEntryIsRemoved_shouldContinueAcrossWraparound() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var keys = (0..<100).map { _ in TestKey() }
        let value = TestValue()
        for key in keys {
            map.setObject(value, forKey: key)
        }

        // -- Act --
        // Remove entries in both directions while reads advance cleanup through the remaining list.
        for index in stride(from: 0, to: 100, by: 2) {
            map.removeObject(forKey: keys[index])
            XCTAssertTrue(map.object(forKey: keys[index + 1]) === value)
        }
        for index in stride(from: 99, through: 1, by: -2) {
            map.removeObject(forKey: keys[index])
        }
        keys.removeAll()
        map.prune()

        // -- Assert --
        XCTAssertEqual(map.count(), 0)
    }

    func testDeinit_whenEntriesRemain_shouldReleaseValues() {
        // -- Arrange --
        let keys = (0..<5_000).map { _ in TestKey() }
        weak var retainedValue: TestValue?

        // -- Act --
        autoreleasepool {
            let map = SentryWeakMap<TestKey, TestValue>()
            let value = TestValue()
            retainedValue = value
            for key in keys {
                map.setObject(value, forKey: key)
            }
            XCTAssertNotNil(retainedValue)
        }

        // -- Assert --
        withExtendedLifetime(keys) {
            XCTAssertNil(retainedValue)
        }
    }

    func testSetObject_whenNewEntriesKeepArriving_shouldRevisitEarlierDeadKeys() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        var earlierKey: TestKey? = TestKey()
        weak var earlierValue: TestValue?
        autoreleasepool {
            let value = TestValue()
            earlierValue = value
            map.setObject(value, forKey: earlierKey)
        }
        let liveKeys = (0..<100).map { _ in TestKey() }
        for key in liveKeys {
            map.setObject(TestValue(), forKey: key)
        }
        earlierKey = nil

        // -- Act --
        // Cleanup must revisit earlier entries, not just chase a continuously growing tail.
        for _ in 0..<1_000 {
            autoreleasepool {
                let key = TestKey()
                map.setObject(TestValue(), forKey: key)
            }
        }

        // -- Assert --
        withExtendedLifetime(liveKeys) {
            XCTAssertNil(earlierValue)
        }
    }

    func testSetObject_whenLiveAndShortLivedKeysAreMixed_shouldEventuallyReclaimDeadEntries() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        let liveKeys = (0..<5_000).map { _ in TestKey() }
        let value = TestValue()

        // -- Act --
        for key in liveKeys {
            map.setObject(value, forKey: key)
            autoreleasepool {
                let shortLivedKey = TestKey()
                map.setObject(value, forKey: shortLivedKey)
            }
        }
        let retainedEntriesAfterInsertion = map.count()
        for _ in 0..<retainedEntriesAfterInsertion {
            XCTAssertTrue(map.object(forKey: liveKeys[0]) === value)
        }

        // -- Assert --
        print("[GH-9536] Mixed lifetime workload: \(retainedEntriesAfterInsertion) entries retained after 5,000 live and 5,000 short-lived insertions")
        withExtendedLifetime(liveKeys) {
            XCTAssertEqual(map.count(), 5_000)
        }
    }

    func testSetObject_whenKeysAreShortLived_shouldKeepStorageBounded() {
        // -- Arrange --
        let map = SentryWeakMap<TestKey, TestValue>()
        weak var releasedValue: TestValue?

        // -- Act --
        for _ in 0..<10_000 {
            autoreleasepool {
                let key = TestKey()
                let value = TestValue()
                if releasedValue == nil {
                    releasedValue = value
                }
                map.setObject(value, forKey: key)
            }
        }

        // -- Assert --
        XCTAssertLessThanOrEqual(map.count(), 128)
        map.prune()
        XCTAssertEqual(map.count(), 0)
        XCTAssertNil(releasedValue)
    }

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

    func testObjectForKey_whenReadsContinue_shouldEventuallyPruneWeakReferences() {
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
        for _ in 0..<1_000 {
            XCTAssertTrue(map.object(forKey: key2) === value2)
        }
        let sizeAfterPrune = map.count()

        // -- Assert --
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

    func testSetObject_whenWritesContinue_shouldEventuallyPruneWeakReferences() {
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
        for _ in 0..<1_000 {
            map.setObject(value2B, forKey: key2)
        }
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

    func testRemoveObjectForKey_whenRemovalsContinue_shouldEventuallyPruneWeakReferences() {
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
        for _ in 0..<1_000 {
            map.removeObject(forKey: key2)
        }
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
