#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
@_implementationOnly import KSCrashInstallations
import Foundation

extension SentryKSCrash {
    /// Terminal KSCrash filter that converts dictionary reports into fatal Sentry events.
    final class ReportFilter: NSObject, CrashReportFilter {
        private let reportProcessor: SentryStoredCrashReportProcessor

        init(reportProcessor: SentryStoredCrashReportProcessor) {
            self.reportProcessor = reportProcessor
        }

        func filterReports(
            _ reports: [any CrashReport],
            onCompletion: (([any CrashReport]?, (any Error)?) -> Void)? = nil
        ) {
            var processedReports: [any CrashReport] = []

            for report in reports {
                guard let dictionaryReport = report as? CrashReportDictionary else {
                    SentrySDKLog.error("Discarding unsupported KSCrash report type.")
                    continue
                }

                do {
                    try reportProcessor.process(report: dictionaryReport.value)
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
