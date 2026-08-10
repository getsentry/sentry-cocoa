#if SDK_V10
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashInstallations
internal import _SentryPrivate
import Foundation

extension SentryKSCrash {
    /// Terminal KSCrash filter that converts dictionary reports into fatal Sentry events.
    final class ReportFilter: NSObject, CrashReportFilter {
        private let core: ReportFilterCore

        init(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper,
            processingSession: ReportProcessingSession
        ) {
            core = ReportFilterCore(
                reportProcessor: reportProcessor,
                dispatchQueue: dispatchQueue,
                processingSession: processingSession
            )
        }

        func filterReports(
            _ reports: [any CrashReport],
            onCompletion: (([any CrashReport]?, (any Error)?) -> Void)? = nil
        ) {
            core.filterReports(
                reports,
                reportDictionary: { ($0 as? CrashReportDictionary)?.value }
            ) { result in
                switch result {
                case .success(let reports):
                    onCompletion?(reports, nil)
                case .failure(let error):
                    onCompletion?([], error)
                }
            }
        }
    }
}
#endif
