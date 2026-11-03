#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@testable import Sentry
#endif
import SentryTestUtils
import XCTest

final class SentryOnceTests: XCTestCase {
    func testCallAsFunction_whenCalledRepeatedly_shouldExecuteOperationOnce() {
        // -- Arrange --
        let invocations = Invocations<Void>()
        let once = SentryOnce { invocations.record(()) }

        // -- Act --
        once()
        once()

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
    }

    func testCallAsFunction_whenCalledWithDifferentInputs_shouldUseFirstInput() {
        // -- Arrange --
        let invocations = Invocations<Int>()
        let once = SentryOnce<Int> { invocations.record($0) }

        // -- Act --
        once(42)
        once(99)

        // -- Assert --
        XCTAssertEqual(invocations.invocations, [42])
    }

    func testCallAsFunction_whenCalledWithTwoInputs_shouldUseFirstTuple() {
        // -- Arrange --
        let invocations = Invocations<(Int, Double)>()
        let once = SentryOnce<(Int, Double)> { (number: Int, fraction: Double) in
            invocations.record((number, fraction))
        }

        // -- Act --
        once((42, 3.14))
        once((99, 2.5))

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?.0, 42)
        XCTAssertEqual(invocations.first?.1, 3.14)
    }

    func testCallAsFunction_whenCalledWithThreeInputs_shouldUseFirstTuple() {
        // -- Arrange --
        let invocations = Invocations<(Int, Double, String)>()
        let once = SentryOnce<(Int, Double, String)> { (number: Int, fraction: Double, text: String) in
            invocations.record((number, fraction, text))
        }

        // -- Act --
        once((42, 3.14, "first"))
        once((99, 2.5, "second"))

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?.0, 42)
        XCTAssertEqual(invocations.first?.1, 3.14)
        XCTAssertEqual(invocations.first?.2, "first")
    }

    func testCallAsFunction_whenCalledConcurrently_shouldExecuteOperationOnce() {
        // -- Arrange --
        let invocations = Invocations<Int>()
        let operations = (0..<1_000).map { index in
            SentryOnce { invocations.record(index) }
        }

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            for once in operations {
                once()
            }
        }

        // -- Assert --
        XCTAssertEqual(invocations.count, 1_000)
        XCTAssertEqual(Set(invocations.invocations), Set(0..<1_000))
    }

    func testCallAsFunction_whenCalledConcurrentlyWithInputs_shouldUseOneCallersInput() {
        // -- Arrange --
        let invocations = Invocations<Int>()
        let once = SentryOnce<Int> { invocations.record($0) }

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 100) { input in
            once(input)
        }

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        XCTAssertTrue(invocations.first.map { (0..<100).contains($0) } ?? false)
    }

    func testCallAsFunction_whenCalledReentrantly_shouldExecuteOperationOnce() {
        // -- Arrange --
        let invocations = Invocations<Void>()
        var once: SentryOnce<Void>?
        once = SentryOnce {
            invocations.record(())
            once?()
        }

        // -- Act --
        once?()

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
    }

    func testCallAsFunction_whenOperationIsRunning_shouldAllowOtherCallsToReturn() {
        // -- Arrange --
        let operationStarted = DispatchSemaphore(value: 0)
        let finishOperation = DispatchSemaphore(value: 0)
        let operationFinished = expectation(description: "Operation finished")
        let laterCallReturned = expectation(description: "Later call returned")
        let once = SentryOnce {
            operationStarted.signal()
            _ = finishOperation.wait(timeout: .now() + 5)
        }
        defer { finishOperation.signal() }

        // -- Act --
        DispatchQueue.global().async {
            once()
            operationFinished.fulfill()
        }
        XCTAssertEqual(operationStarted.wait(timeout: .now() + 5), .success)
        DispatchQueue.global().async {
            once()
            laterCallReturned.fulfill()
        }

        // -- Assert --
        wait(for: [laterCallReturned], timeout: 2)
        finishOperation.signal()
        wait(for: [operationFinished], timeout: 5)
    }
}
