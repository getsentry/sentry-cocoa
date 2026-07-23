#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
import Foundation

extension SentryKSCrash {
    /// Report filtering logic independent of KSCrash package types.
    ///
    /// The caller provides the boundary between its report representation and the dictionary
    /// consumed by `SentryStoredCrashReportProcessor`. Successfully processed reports are returned
    /// unchanged so adapters can preserve the report objects expected by their filtering API.
    final class ReportFilterCore {
        private let reportProcessor: SentryStoredCrashReportProcessor

        init(reportProcessor: SentryStoredCrashReportProcessor) {
            self.reportProcessor = reportProcessor
        }

        func filterReports<Report>(
            _ reports: [Report],
            reportDictionary: (Report) -> [AnyHashable: Any]?,
            onCompletion: (([Report]?, (any Error)?) -> Void)? = nil
        ) {
            var processedReports: [Report] = []

            for report in reports {
                guard let dictionary = reportDictionary(report) else {
                    SentrySDKLog.error("Discarding unsupported KSCrash report type.")
                    continue
                }

                do {
                    try reportProcessor.process(report: dictionary)
                    processedReports.append(report)
                } catch {
                    SentrySDKLog.error(
                        "Discarding unprocessable KSCrash report: \(error.localizedDescription)"
                    )
                }
            }

            // ReportStore's .onSuccess cleanup policy deletes the whole attempted batch only when
            // the completion error is nil. Treat unprocessable reports as consumed so they cannot
            // permanently block later valid reports.
            onCompletion?(processedReports, nil)
        }
    }
}
#endif
