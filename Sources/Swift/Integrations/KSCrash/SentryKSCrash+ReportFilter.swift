#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
@_implementationOnly import KSCrashInstallations
import Foundation

extension SentryKSCrash {
    /// Terminal KSCrash filter that converts dictionary reports into fatal Sentry events.
    final class ReportFilter: NSObject, CrashReportFilter {
        private static let errorDomain = "io.sentry.kscrash-report-filter"
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
                    let error = NSError(
                        domain: Self.errorDomain,
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "KSCrash supplied an unsupported crash report type."
                        ]
                    )
                    onCompletion?(processedReports, error)
                    return
                }

                do {
                    try reportProcessor.process(report: dictionaryReport.value)
                    processedReports.append(report)
                } catch {
                    onCompletion?(processedReports, error)
                    return
                }
            }

            onCompletion?(processedReports, nil)
        }
    }
}
#endif
