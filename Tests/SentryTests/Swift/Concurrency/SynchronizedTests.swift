@testable import Sentry
import XCTest

final class SynchronizedTests: XCTestCase {

    func testSynchronized_whenOperationReturnsValue_shouldReturnValue() {
        // -- Arrange --
        let object = SynchronizedObject()

        // -- Act --
        let result = synchronized(object) {
            object.value = 42
            return object.value
        }

        // -- Assert --
        XCTAssertEqual(result, 42)
    }

    func testSynchronized_whenCalledConcurrentlyWithSameObject_shouldSerializeOperations() {
        // -- Arrange --
        let object = SynchronizedObject()

        // -- Act --
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 1_000) { _ in
            synchronized(object) {
                object.value += 1
            }
        }

        // -- Assert --
        XCTAssertEqual(object.value, 10_010)
    }

    func testSynchronized_whenCalledRecursivelyWithSameObject_shouldExecuteNestedOperation() {
        // -- Arrange --
        let object = SynchronizedObject()

        // -- Act --
        let result = synchronized(object) {
            object.value += 1
            return synchronized(object) {
                object.value += 1
                return object.value
            }
        }

        // -- Assert --
        XCTAssertEqual(result, 2)
    }

    func testSynchronized_whenOperationThrows_shouldPropagateErrorAndReleaseLock() {
        // -- Arrange --
        let object = SynchronizedObject()
        let expectedError = TestError.operationFailed
        let lockAcquiredFromAnotherThread = expectation(description: "Lock acquired from another thread")

        // -- Act --
        XCTAssertThrowsError(try synchronized(object) {
            throw expectedError
        }) { error in
            XCTAssertEqual(error as? TestError, expectedError)
        }

        DispatchQueue.global().async {
            synchronized(object) {
                object.value += 1
                lockAcquiredFromAnotherThread.fulfill()
            }
        }

        // -- Assert --
        wait(for: [lockAcquiredFromAnotherThread], timeout: 1)
        XCTAssertEqual(object.value, 1)
    }

    func testSynchronized_whenCalledWithDifferentObjects_shouldExecuteIndependently() {
        // -- Arrange --
        let firstObject = SynchronizedObject()
        let secondObject = SynchronizedObject()
        let releaseFirstOperation = DispatchSemaphore(value: 0)
        let firstOperationEntered = expectation(description: "First operation entered")
        let firstOperationFinished = expectation(description: "First operation finished")
        let secondOperationEntered = expectation(description: "Second operation entered")

        DispatchQueue.global().async {
            synchronized(firstObject) {
                firstObject.value += 1
                firstOperationEntered.fulfill()
                releaseFirstOperation.wait()
            }
            firstOperationFinished.fulfill()
        }
        wait(for: [firstOperationEntered], timeout: 1)

        // -- Act --
        DispatchQueue.global().async {
            synchronized(secondObject) {
                secondObject.value += 1
                secondOperationEntered.fulfill()
            }
        }

        // -- Assert --
        wait(for: [secondOperationEntered], timeout: 1)
        XCTAssertEqual(secondObject.value, 1)
        releaseFirstOperation.signal()
        wait(for: [firstOperationFinished], timeout: 1)
        XCTAssertEqual(firstObject.value, 1)
    }

    private enum TestError: Error {
        case operationFailed
    }
}

@objcMembers
private final class SynchronizedObject: NSObject {
    var value = 0
}
