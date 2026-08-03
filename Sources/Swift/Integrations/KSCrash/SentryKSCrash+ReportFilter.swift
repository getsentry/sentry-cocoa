#if ENABLE_KSCRASH
// swiftlint:disable:next no_implementation_only_import
@_implementationOnly import KSCrashRecording
internal import _SentryPrivate
import Foundation

extension SentryKSCrash {
    /// Terminal KSCrash filter that converts dictionary reports into fatal Sentry events.
    final class ReportFilter: NSObject, CrashReportFilter {
        private let core: ReportFilterCore

        init(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper
        ) {
            core = ReportFilterCore(reportProcessor: reportProcessor, dispatchQueue: dispatchQueue)
        }

        func filterReports(
            _ reports: [any CrashReport],
            onCompletion: (([any CrashReport]?, (any Error)?) -> Void)? = nil
        ) {
            core.filterReports(
                reports,
                reportDictionary: { ($0 as? CrashReportDictionary)?.value },
                onCompletion: onCompletion
            )
        }
    }
}
#endif
