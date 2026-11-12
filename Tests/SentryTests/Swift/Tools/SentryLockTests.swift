#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
#else
@testable import Sentry
#endif
import XCTest

final class SentryLockTests: XCTestCase {

    func testWithLock_shouldReturnTheResultOfTheBody() {
        // -- Arrange --
        let sut = SentryLock()

        // -- Act --
        let result = sut.withLock { 42 }

        // -- Assert --
        XCTAssertEqual(result, 42)
    }

    func testWithLock_whenBodyThrows_shouldPropagateErrorAndReleaseTheLock() {
        // -- Arrange --
        let sut = SentryLock()

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.withLock {
            throw NSError(domain: "test", code: 1)
        })
        XCTAssertEqual(sut.withLock { 42 }, 42)
    }

    func testWithLock_whenCalledConcurrently_shouldSerializeTheBodies() {
        // -- Arrange --
        let sut = SentryLock()
        let iterations = 1_000
        // Not synchronized on its own, so a lost update shows that two bodies ran at once.
        let counter = Counter()

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            sut.withLock { counter.value += 1 }
        }

        // -- Assert --
        XCTAssertEqual(counter.value, iterations)
    }

    func testWithLockIfAvailable_whenLockIsFree_shouldRunTheBody() {
        // -- Arrange --
        let sut = SentryLock()

        // -- Act --
        let result = sut.withLockIfAvailable { 42 }

        // -- Assert --
        XCTAssertEqual(result, 42)
    }

    func testWithLockIfAvailable_whenLockIsHeld_shouldReturnNil() {
        // -- Arrange --
        let sut = SentryLock()

        // -- Act --
        let result = sut.withLock {
            sut.withLockIfAvailable { 42 }
        }

        // -- Assert --
        XCTAssertNil(result)
    }

    private final class Counter: @unchecked Sendable {
        var value = 0
    }
}
