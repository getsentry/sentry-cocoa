@testable import Sentry
import XCTest

final class SentryMutexTests: XCTestCase {

    func testWithLock_whenReadingValue_shouldReturnCurrentValue() {
        let mutex = SentryMutex(42)

        let result = mutex.withLock { $0 }

        XCTAssertEqual(result, 42)
    }

    func testWithLock_whenMutatingValue_shouldUpdateValue() {
        let mutex = SentryMutex(0)

        mutex.withLock { $0 = 99 }

        let result = mutex.withLock { $0 }
        XCTAssertEqual(result, 99)
    }

    func testWithLock_whenReturningTransformedValue_shouldReturnResult() {
        let mutex = SentryMutex([1, 2, 3])

        let count = mutex.withLock { $0.count }

        XCTAssertEqual(count, 3)
    }

    func testWithLock_whenBodyThrows_shouldPropagateError() {
        let mutex = SentryMutex(0)

        XCTAssertThrowsError(try mutex.withLock { _ in
            throw NSError(domain: "test", code: 1)
        })

        // Lock should still be usable after a throw
        mutex.withLock { $0 = 42 }
        XCTAssertEqual(mutex.withLock { $0 }, 42)
    }

    func testWithLockIfAvailable_whenLockIsFree_shouldExecuteBody() {
        let mutex = SentryMutex("hello")

        let result = mutex.withLockIfAvailable { value -> String in
            value = "world"
            return value
        }

        XCTAssertEqual(result, "world")
        XCTAssertEqual(mutex.withLock { $0 }, "world")
    }

    func testWithLockIfAvailable_whenLockIsHeld_shouldReturnNil() {
        let mutex = SentryMutex("hello")

        let outer = mutex.withLock { value -> String in
            let inner = mutex.withLockIfAvailable { $0 }
            XCTAssertNil(inner)
            return value
        }

        XCTAssertEqual(outer, "hello")
    }

    func testWithLockIfAvailable_whenBodyThrows_shouldPropagateError() {
        let mutex = SentryMutex(0)

        XCTAssertThrowsError(try mutex.withLockIfAvailable { _ in
            throw NSError(domain: "test", code: 1)
        })

        // Lock should still be usable after a throw
        mutex.withLock { $0 = 42 }
        XCTAssertEqual(mutex.withLock { $0 }, 42)
    }

    func testWithLock_whenDictionaryValue_shouldSupportMutations() {
        let mutex = SentryMutex<[String: Int]>([:])

        mutex.withLock {
            $0["a"] = 1
            $0["b"] = 2
        }

        let result = mutex.withLock { $0 }
        XCTAssertEqual(result, ["a": 1, "b": 2])
    }

    func testWithLock_whenConcurrentAccess_shouldNotRace() {
        let mutex = SentryMutex(0)

        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000, writeWork: { _ in
            mutex.withLock { $0 += 1 }
        })

        let result = mutex.withLock { $0 }
        XCTAssertEqual(result, 10_010)
    }

    func testWithLock_whenConcurrentReadWrite_shouldNotRace() {
        let mutex = SentryMutex<[String: Int]>([:])

        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 100, writeWork: { i in
            mutex.withLock { $0["\(i)"] = i }
        }, readWork: {
            _ = mutex.withLock { $0.count }
        })

        let finalCount = mutex.withLock { $0.count }
        XCTAssertEqual(finalCount, 101)
    }
}
