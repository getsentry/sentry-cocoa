#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
import Foundation
import XCTest

final class SentryKSCrashReportStoreSenderTests: XCTestCase {
    func testSendAllReports_whenReportIDsAreEmpty_shouldCleanupWithoutSending() {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var cleanupInvocationCount = 0
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, _ in
                sentReportIDs.append(reportID)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            }
        )

        // -- Act --
        sut.sendAllReports([], prioritizing: { _ in false })

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [])
        XCTAssertEqual(cleanupInvocationCount, 1)
    }

    func testSendAllReports_whenAllReportsFail_shouldAttemptEveryReportAndCleanupOnce() throws {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var pendingCompletions: [(Int, (any Error)?) -> Void] = []
        var cleanupInvocationCount = 0
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                sentReportIDs.append(reportID)
                pendingCompletions.append(onCompletion)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            }
        )
        let error = NSError(domain: "test", code: 1)

        // -- Act --
        sut.sendAllReports([1, 2, 3], prioritizing: { _ in false })

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
        XCTAssertEqual(cleanupInvocationCount, 1)
    }

    func testSendAllReports_whenRetryableFailureFollowsSuccess_shouldRetryOnlyFailedReport() throws {
        // -- Arrange --
        var storedReportIDs = Set<Int64>([1, 2])
        var sentReportIDs: [Int64] = []
        var pendingCompletions: [
            (reportID: Int64, completion: (Int, (any Error)?) -> Void)
        ] = []
        var cleanupInvocationCount = 0
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                sentReportIDs.append(reportID)
                pendingCompletions.append((reportID, onCompletion))
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            }
        )

        // -- Act --
        sut.sendAllReports([1, 2], prioritizing: { _ in false })

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
        sut.sendAllReports(storedReportIDs.sorted(), prioritizing: { _ in false })
        let retriedReport = try XCTUnwrap(pendingCompletions.first)
        pendingCompletions.removeFirst()
        storedReportIDs.remove(retriedReport.reportID)
        retriedReport.completion(1, nil)

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [1, 2, 2])
        XCTAssertEqual(storedReportIDs, [])
        XCTAssertEqual(cleanupInvocationCount, 2)
    }

    func testSendAllReports_whenReportIsPrioritized_shouldSendItBeforeRemainingReports() {
        // -- Arrange --
        var sentReportIDs: [Int64] = []
        var cleanupInvocationCount = 0
        let sut = SentryKSCrash.ReportStoreSender(
            sendReport: { reportID, onCompletion in
                sentReportIDs.append(reportID)
                onCompletion(1, nil)
            },
            cleanupOrphanedRunSidecars: {
                cleanupInvocationCount += 1
            }
        )

        // -- Act --
        sut.sendAllReports([1, 2, 3], prioritizing: { $0 == 2 })

        // -- Assert --
        XCTAssertEqual(sentReportIDs, [2, 1, 3])
        XCTAssertEqual(cleanupInvocationCount, 1)
    }
}
#endif
