#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

final class SentryKSCrashReportStoreSenderTests: XCTestCase {
    func testSendAllReports_whenReportIDsAreEmpty_shouldCleanupWithoutSending() {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var prioritizedReportsCompletedInvocationCount = 0
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, _ in
                sentReportIDs.append(reportID)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )

        // -- Act --
        sut.sendAllReports(
            [],
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {
                prioritizedReportsCompletedInvocationCount += 1
            }
        )

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [])
        XCTAssertEqual(prioritizedReportsCompletedInvocationCount, 0)
        XCTAssertEqual(cleanupInvocationCount, 1)
    }

    func testSendAllReports_whenAllReportsFail_shouldAttemptEveryReportAndCleanupOnce() throws {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var pendingCompletions: [(Int, (any Error)?) -> Void] = []
        var prioritizedReportsCompletedInvocationCount = 0
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                sentReportIDs.append(reportID)
                pendingCompletions.append(onCompletion)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )
        let error = NSError(domain: "test", code: 1)

        // -- Act --
        sut.sendAllReports(
            [1, 2, 3],
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {
                prioritizedReportsCompletedInvocationCount += 1
            }
        )

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1])
        XCTAssertEqual(cleanupInvocationCount, 0)

        // -- Act --
        let firstCompletion = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        firstCompletion(0, error)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1, 2])
        XCTAssertEqual(cleanupInvocationCount, 0)

        // -- Act --
        let secondCompletion = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        secondCompletion(0, error)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1, 2, 3])
        XCTAssertEqual(cleanupInvocationCount, 0)

        // -- Act --
        let thirdCompletion = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        thirdCompletion(0, error)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1, 2, 3])
        XCTAssertEqual(pendingCompletions.count, 0)
        XCTAssertEqual(prioritizedReportsCompletedInvocationCount, 0)
        XCTAssertEqual(cleanupInvocationCount, 1)
    }

    func testSendAllReports_whenRetryableFailureFollowsSuccess_shouldRetryOnlyFailedReport() throws {
        // -- Arrange --
        var storedReportIDs = Set<Int64>([1, 2])
        var sentReportIDs: [Int64] = []
        var pendingCompletions: [
            (reportID: Int64, completion: (Int, (any Error)?) -> Void)
        ] = []
        var prioritizedReportsCompletedInvocationCount = 0
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                sentReportIDs.append(reportID)
                pendingCompletions.append((reportID, onCompletion))
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )

        // -- Act --
        sut.sendAllReports(
            [1, 2],
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {
                prioritizedReportsCompletedInvocationCount += 1
            }
        )

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1])

        // -- Act --
        let successfulReport = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        // Model KSCrash's .onSuccess cleanup, which runs before its completion callback.
        storedReportIDs.remove(successfulReport.reportID)
        successfulReport.completion(1, nil)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1, 2])

        // -- Act --
        let retryableReport = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        retryableReport.completion(0, NSError(domain: "test", code: 1))

        // -- Assert --
        XCTAssertEqual(storedReportIDs, [2])
        XCTAssertEqual(cleanupInvocationCount, 1)

        // -- Act --
        sut.sendAllReports(
            storedReportIDs.sorted(),
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {
                prioritizedReportsCompletedInvocationCount += 1
            }
        )
        let retriedReport = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        storedReportIDs.remove(retriedReport.reportID)
        retriedReport.completion(1, nil)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1, 2, 2])
        XCTAssertEqual(storedReportIDs, [])
        XCTAssertEqual(prioritizedReportsCompletedInvocationCount, 0)
        XCTAssertEqual(cleanupInvocationCount, 2)
    }

    func testSendAllReports_whenCancelledAfterActiveReportStarts_shouldStopBeforeNextReportAndCleanup() throws {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var pendingCompletion: ((Int, (any Error)?) -> Void)?
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                sentReportIDs.append(reportID)
                pendingCompletion = onCompletion
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )
        sut.sendAllReports(
            [1, 2],
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {}
        )

        // -- Act --
        processingSession.cancel()
        try XCTUnwrap(pendingCompletion)(0, SentryKSCrash.ReportProcessingSession.cancellationError)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1])
        XCTAssertEqual(cleanupInvocationCount, 0)
    }

    func testSendAllReports_whenAlreadyCancelled_shouldNotSendOrCleanup() {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        processingSession.cancel()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, _ in
                sentReportIDs.append(reportID)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )

        // -- Act --
        sut.sendAllReports(
            [1],
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {}
        )
        sut.sendAllReports(
            [],
            prioritizing: { _ in false },
            onPrioritizedReportsCompleted: {}
        )

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [])
        XCTAssertEqual(cleanupInvocationCount, 0)
    }

    func testSendAllReports_whenMultipleReportsArePrioritized_shouldCompletePhaseBeforeRemainingReports() {
        // -- Arrange --
        var deliveryEvents: [String] = []
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                deliveryEvents.append("report-\(reportID)")
                onCompletion(1, nil)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )

        // -- Act --
        sut.sendAllReports(
            [1, 2, 3, 4],
            prioritizing: { $0.isMultiple(of: 2) },
            onPrioritizedReportsCompleted: {
                deliveryEvents.append("prioritized-completed")
            }
        )

        // -- Assert --
        XCTAssertEqual(
            deliveryEvents,
            ["report-2", "report-4", "prioritized-completed", "report-1", "report-3"]
        )
        XCTAssertEqual(cleanupInvocationCount, 1)
    }

    func testSendAllReports_whenPrioritizedReportsFail_shouldCompletePhaseAndSendRemainingReports() throws {
        // -- Arrange --
        var deliveryEvents: [String] = []
        var pendingCompletions: [(Int, (any Error)?) -> Void] = []
        var cleanupInvocationCount = 0
        let processingSession = SentryKSCrash.ReportProcessingSession()
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                deliveryEvents.append("report-\(reportID)")
                pendingCompletions.append(onCompletion)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            },
            processingSession: processingSession
        )
        let error = NSError(domain: "test", code: 1)

        sut.sendAllReports(
            [1, 2, 3],
            prioritizing: { $0 < 3 },
            onPrioritizedReportsCompleted: {
                deliveryEvents.append("prioritized-completed")
            }
        )

        // -- Act --
        let firstPrioritizedCompletion = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        firstPrioritizedCompletion(0, error)

        // -- Assert --
        XCTAssertEqual(deliveryEvents, ["report-1", "report-2"])
        XCTAssertEqual(cleanupInvocationCount, 0)

        // -- Act --
        let secondPrioritizedCompletion = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        secondPrioritizedCompletion(0, error)

        // -- Assert --
        XCTAssertEqual(
            deliveryEvents,
            ["report-1", "report-2", "prioritized-completed", "report-3"]
        )
        XCTAssertEqual(cleanupInvocationCount, 0)

        // -- Act --
        let remainingCompletion = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        remainingCompletion(1, nil)

        // -- Assert --
        XCTAssertEqual(cleanupInvocationCount, 1)
    }
}
#endif
