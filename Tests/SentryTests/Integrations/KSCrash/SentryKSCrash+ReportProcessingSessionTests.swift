#if SDK_V10
@_spi(Private) @testable import Sentry
import XCTest

final class SentryKSCrashReportProcessingSessionTests: XCTestCase {
    func testCancel_whenOperationIsPending_shouldInvokeCancellationOnce() throws {
        // -- Arrange --
        let sut = SentryKSCrash.ReportProcessingSession()
        var cancellationInvocationCount = 0
        let operation = try XCTUnwrap(sut.register {
            cancellationInvocationCount += 1
        })

        // -- Act --
        sut.cancel()
        sut.cancel()
        operation.complete {
            cancellationInvocationCount += 1
        }

        // -- Assert --
        XCTAssertTrue(sut.isCancelled)
        XCTAssertEqual(cancellationInvocationCount, 1)
    }

    func testComplete_whenLateResultsFollowCancellation_shouldNotCompleteTwice() throws {
        // -- Arrange --
        let sut = SentryKSCrash.ReportProcessingSession()
        var results: [String] = []
        let operation = try XCTUnwrap(sut.register {
            results.append("cancelled")
        })
        XCTAssertTrue(operation.beginProcessing())

        // -- Act --
        sut.cancel()
        operation.complete {
            results.append("success")
        }
        operation.complete {
            results.append("error")
        }

        // -- Assert --
        XCTAssertEqual(results, ["cancelled"])
    }

    func testCancel_whenRacingNormalCompletion_shouldCompleteExactlyOnce() throws {
        // -- Arrange --
        let sut = SentryKSCrash.ReportProcessingSession()
        let results = SentryMutex<[String]>([])
        let operation = try XCTUnwrap(sut.register {
            results.withLock { $0.append("cancelled") }
        })
        XCTAssertTrue(operation.beginProcessing())
        let start = DispatchSemaphore(value: 0)
        let workersFinished = expectation(description: "Racing workers finished")
        workersFinished.expectedFulfillmentCount = 2

        DispatchQueue.global().async {
            start.wait()
            sut.cancel()
            workersFinished.fulfill()
        }
        DispatchQueue.global().async {
            start.wait()
            operation.complete {
                results.withLock { $0.append("completed") }
            }
            workersFinished.fulfill()
        }

        // -- Act --
        start.signal()
        start.signal()
        wait(for: [workersFinished], timeout: 1)

        // -- Assert --
        XCTAssertEqual(results.withLock { $0.count }, 1)
    }

    func testRegister_whenSessionIsCancelled_shouldCancelImmediately() {
        // -- Arrange --
        let sut = SentryKSCrash.ReportProcessingSession()
        sut.cancel()
        var cancellationInvocationCount = 0

        // -- Act --
        let operation = sut.register {
            cancellationInvocationCount += 1
        }

        // -- Assert --
        XCTAssertNil(operation)
        XCTAssertEqual(cancellationInvocationCount, 1)
    }

    func testCancel_whenCallbackReentersSession_shouldNotDeadlock() {
        // -- Arrange --
        let sut = SentryKSCrash.ReportProcessingSession()
        var reentrantCancellationInvocationCount = 0
        _ = sut.register {
            XCTAssertTrue(sut.isCancelled)
            sut.cancel()
            _ = sut.register {
                reentrantCancellationInvocationCount += 1
            }
        }

        // -- Act --
        sut.cancel()

        // -- Assert --
        XCTAssertEqual(reentrantCancellationInvocationCount, 1)
    }

    func testCancel_whenCaptureIsCommitted_shouldAllowNaturalCompletion() throws {
        // -- Arrange --
        let sut = SentryKSCrash.ReportProcessingSession()
        var cancellationInvocationCount = 0
        var completionInvocationCount = 0
        let operation = try XCTUnwrap(sut.register {
            cancellationInvocationCount += 1
        })
        XCTAssertTrue(operation.beginProcessing())
        XCTAssertTrue(operation.commitCapture())

        // -- Act --
        sut.cancel()
        operation.complete {
            completionInvocationCount += 1
        }
        operation.complete {
            completionInvocationCount += 1
        }

        // -- Assert --
        XCTAssertEqual(cancellationInvocationCount, 0)
        XCTAssertEqual(completionInvocationCount, 1)
    }
}
#endif
