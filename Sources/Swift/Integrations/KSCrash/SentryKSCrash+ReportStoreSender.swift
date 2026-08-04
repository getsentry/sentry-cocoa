#if ENABLE_KSCRASH
import Foundation

extension SentryKSCrash {
    /// Sends stored reports sequentially so each report is its own cleanup and retry unit.
    /// A per-report error does not stop later IDs; cleanup runs only after every completion.
    /// Prioritized reports run first so startup crashes can complete synchronously before regular
    /// report delivery moves processing to the background queue.
    final class ReportStoreSender {
        typealias SendReport = (
            _ reportID: Int64,
            _ onCompletion: @escaping (_ processedReportCount: Int, _ error: (any Error)?) -> Void
        ) -> Void

        private let sendReport: SendReport
        private let cleanupOrphanedRunSidecars: () -> Void

        init(
            sendReport: @escaping SendReport,
            cleanupOrphanedRunSidecars: @escaping () -> Void
        ) {
            self.sendReport = sendReport
            self.cleanupOrphanedRunSidecars = cleanupOrphanedRunSidecars
        }

        func sendAllReports(
            _ reportIDs: [Int64],
            prioritizing shouldPrioritize: (Int64) -> Bool,
            onPrioritizedReportsCompleted: @escaping () -> Void
        ) {
            var prioritizedReportIDs: [Int64] = []
            var remainingReportIDs: [Int64] = []
            for reportID in reportIDs {
                if shouldPrioritize(reportID) {
                    prioritizedReportIDs.append(reportID)
                } else {
                    remainingReportIDs.append(reportID)
                }
            }

            guard !prioritizedReportIDs.isEmpty else {
                sendReports(
                    remainingReportIDs[...],
                    onCompletion: cleanupOrphanedRunSidecars
                )
                return
            }

            sendReports(prioritizedReportIDs[...]) { [self] in
                onPrioritizedReportsCompleted()
                sendReports(
                    remainingReportIDs[...],
                    onCompletion: cleanupOrphanedRunSidecars
                )
            }
        }

        private func sendReports(
            _ reportIDs: ArraySlice<Int64>,
            onCompletion: @escaping () -> Void
        ) {
            guard let reportID = reportIDs.first else {
                onCompletion()
                return
            }

            sendReport(reportID) { [self] processedReportCount, error in
                if let error = error {
                    SentrySDKLog.error(
                        "Error processing KSCrash report \(reportID): \(error.localizedDescription)"
                    )
                } else {
                    SentrySDKLog.debug(
                        "Processed \(processedReportCount) KSCrash report(s) for report ID \(reportID)"
                    )
                }
                sendReports(reportIDs.dropFirst(), onCompletion: onCompletion)
            }
        }
    }
}
#endif
