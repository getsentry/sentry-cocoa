#if ENABLE_KSCRASH
@_implementationOnly import _SentryPrivate
import Foundation

extension SentryKSCrash {
    /// Report filtering logic independent of KSCrash package types.
    ///
    /// The caller provides the boundary between its report representation and the dictionary
    /// consumed by `SentryStoredCrashReportProcessor`. Each invocation accepts at most one report
    /// so KSCrash can apply cleanup and retry decisions to that report independently.
    ///
    /// Completion contract used with KSCrash's `.onSuccess` cleanup policy:
    /// - Captured report: return the report without an error; KSCrash deletes it.
    /// - Unsupported or permanently invalid report: return no report and no error; KSCrash consumes
    ///   it so it cannot permanently block delivery.
    /// - Retryable failure: return no report and the error; KSCrash retains it for a later launch.
    final class ReportFilterCore {
        private static let startupCrashDurationThreshold: TimeInterval = 2
        private static let startupCrashFlushDuration: TimeInterval = 5
        private static let errorDomain = "io.sentry.kscrash-report-filter"

        private enum ProcessingOutcome<Report> {
            case captured(Report)
            case discarded
            case retry(any Error)
        }

        private let reportProcessor: SentryStoredCrashReportProcessor
        private let dispatchQueue: SentryDispatchQueueWrapper

        init(
            reportProcessor: SentryStoredCrashReportProcessor,
            dispatchQueue: SentryDispatchQueueWrapper
        ) {
            self.reportProcessor = reportProcessor
            self.dispatchQueue = dispatchQueue
        }

        func filterReports<Report>(
            _ reports: [Report],
            reportDictionary: @escaping (Report) -> [AnyHashable: Any]?,
            onCompletion: (([Report]?, (any Error)?) -> Void)? = nil
        ) {
            guard reports.count <= 1 else {
                let error = NSError(
                    domain: Self.errorDomain,
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "KSCrash report delivery must process one report at a time."
                    ]
                )
                onCompletion?([], error)
                return
            }
            guard let report = reports.first else {
                onCompletion?([], nil)
                return
            }

            let isStartupCrash = reportDictionary(report).map(Self.isStartupCrash) ?? false
            if isStartupCrash {
                SentrySDKLog.warning("Startup crash detected.")
                SentrySDKInternal.setDetectedStartUpCrash(true)
                let outcome = Self.processReport(
                    report,
                    reportDictionary: reportDictionary,
                    reportProcessor: reportProcessor
                )
                SentrySDKInternal.flush(timeout: Self.startupCrashFlushDuration)
                Self.complete(outcome, onCompletion: onCompletion)
                return
            }

            dispatchQueue.dispatchAsync { [reportProcessor = self.reportProcessor] in
                let outcome = Self.processReport(
                    report,
                    reportDictionary: reportDictionary,
                    reportProcessor: reportProcessor
                )
                Self.complete(outcome, onCompletion: onCompletion)
            }
        }

        private static func processReport<Report>(
            _ report: Report,
            reportDictionary: (Report) -> [AnyHashable: Any]?,
            reportProcessor: SentryStoredCrashReportProcessor
        ) -> ProcessingOutcome<Report> {
            guard let dictionary = reportDictionary(report) else {
                SentrySDKLog.error("Discarding unsupported KSCrash report type.")
                return .discarded
            }

            do {
                try reportProcessor.process(report: dictionary)
                return .captured(report)
            } catch {
                guard isPermanentProcessingError(error) else {
                    SentrySDKLog.warning(
                        "Deferring KSCrash report processing after retryable error: \(error.localizedDescription)"
                    )
                    return .retry(error)
                }
                SentrySDKLog.error(
                    "Discarding unprocessable KSCrash report: \(error.localizedDescription)"
                )
                return .discarded
            }
        }

        private static func complete<Report>(
            _ outcome: ProcessingOutcome<Report>,
            onCompletion: (([Report]?, (any Error)?) -> Void)?
        ) {
            switch outcome {
            case .captured(let report):
                onCompletion?([report], nil)
            case .discarded:
                onCompletion?([], nil)
            case .retry(let error):
                onCompletion?([], error)
            }
        }

        private static func isPermanentProcessingError(_ error: any Error) -> Bool {
            let error = error as NSError
            guard error.domain == SentryStoredCrashReportProcessorErrorDomain else {
                return false
            }
            return error.code == SentryStoredCrashReportProcessorError.unsupportedReport.rawValue
                || error.code == SentryStoredCrashReportProcessorError.conversionFailed.rawValue
        }

        static func isStartupCrash(_ report: [AnyHashable: Any]) -> Bool {
            guard let duration = durationSinceCrashHandlerInitialization(report) else {
                return false
            }
            return duration > 0 && duration <= startupCrashDurationThreshold
        }

        private static func durationSinceCrashHandlerInitialization(
            _ report: [AnyHashable: Any]
        ) -> TimeInterval? {
            // KSCrash records app_start_time when its System monitor is enabled, so despite the
            // field name it represents crash-handler initialization rather than process launch.
            guard
                let reportContext = report["report"] as? [AnyHashable: Any],
                let systemContext = report["system"] as? [AnyHashable: Any],
                let crashDate = date(from: reportContext["timestamp"]),
                let crashHandlerInitDate = date(from: systemContext["app_start_time"])
            else {
                return nil
            }

            return crashDate.timeIntervalSince(crashHandlerInitDate)
        }

        private static func date(from value: Any?) -> Date? {
            if let value = value as? String {
                return sentry_fromIso8601String(value)
            }
            if let value = value as? NSNumber {
                return Date(timeIntervalSince1970: value.doubleValue)
            }
            return nil
        }
    }
}
#endif
