#if ENABLE_KSCRASH
internal import _SentryPrivate
import Foundation

extension SentryKSCrash {
    protocol StoredCrashReportProcessing {
        func process(
            report: [AnyHashable: Any],
            beforeCapture: @escaping () -> (any Error)?
        ) throws
    }

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

        private let reportProcessor: any StoredCrashReportProcessing
        private let dispatchQueue: SentryDispatchQueueWrapper
        private let processingSession: ReportProcessingSession

        init(
            reportProcessor: any StoredCrashReportProcessing,
            dispatchQueue: SentryDispatchQueueWrapper,
            processingSession: ReportProcessingSession
        ) {
            self.reportProcessor = reportProcessor
            self.dispatchQueue = dispatchQueue
            self.processingSession = processingSession
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

            let operation = processingSession.register {
                onCompletion?([], ReportProcessingSession.cancellationError)
            }
            guard let operation else {
                return
            }

            let isStartupCrash = reportDictionary(report).map(Self.isStartupCrash) ?? false
            if isStartupCrash {
                processStartupReport(
                    report,
                    reportDictionary: reportDictionary,
                    operation: operation,
                    onCompletion: onCompletion
                )
            } else {
                processRegularReport(
                    report,
                    reportDictionary: reportDictionary,
                    operation: operation,
                    onCompletion: onCompletion
                )
            }
        }

        private func processStartupReport<Report>(
            _ report: Report,
            reportDictionary: (Report) -> [AnyHashable: Any]?,
            operation: ReportProcessingSession.Operation,
            onCompletion: (([Report]?, (any Error)?) -> Void)?
        ) {
            guard operation.beginProcessing() else {
                return
            }
            SentrySDKLog.warning("Startup crash detected.")
            SentrySDKInternal.setDetectedStartUpCrash(true)
            let outcome = Self.processReport(
                report,
                reportDictionary: reportDictionary,
                reportProcessor: reportProcessor,
                operation: operation
            )
            // This global flush could target a replacement SDK hub if uninstall/restart races this
            // call. We explicitly accept that very-low-severity timing/lifecycle effect: startup
            // reports are processed synchronously during integration installation, so the race is
            // unlikely, and capture remains isolated by the generation operation.
            SentrySDKInternal.flush(timeout: Self.startupCrashFlushDuration)
            operation.complete {
                Self.complete(outcome, onCompletion: onCompletion)
            }
        }

        private func processRegularReport<Report>(
            _ report: Report,
            reportDictionary: @escaping (Report) -> [AnyHashable: Any]?,
            operation: ReportProcessingSession.Operation,
            onCompletion: (([Report]?, (any Error)?) -> Void)?
        ) {
            dispatchQueue.dispatchAsync { [reportProcessor] in
                guard operation.beginProcessing() else {
                    return
                }
                let outcome = Self.processReport(
                    report,
                    reportDictionary: reportDictionary,
                    reportProcessor: reportProcessor,
                    operation: operation
                )
                operation.complete {
                    Self.complete(outcome, onCompletion: onCompletion)
                }
            }
        }

        private static func processReport<Report>(
            _ report: Report,
            reportDictionary: (Report) -> [AnyHashable: Any]?,
            reportProcessor: any StoredCrashReportProcessing,
            operation: ReportProcessingSession.Operation
        ) -> ProcessingOutcome<Report> {
            guard let dictionary = reportDictionary(report) else {
                SentrySDKLog.error("Discarding unsupported KSCrash report type.")
                return .discarded
            }

            do {
                try reportProcessor.process(report: dictionary) {
                    #if SENTRY_CRASH_E2E
                    if let error = CrashE2ETestHook.retryableProcessingError(for: dictionary) {
                        return error
                    }
                    #endif
                    return operation.commitCapture()
                        ? nil
                        : ReportProcessingSession.cancellationError
                }
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
            // KSCrash can serialize both timestamps with second precision. In that case, a crash
            // during the initialization second has a valid duration of zero. Missing timestamps
            // return nil above, so zero is not an "unknown duration" sentinel here.
            return duration >= 0 && duration <= startupCrashDurationThreshold
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

extension SentryStoredCrashReportProcessor: SentryKSCrash.StoredCrashReportProcessing {}
#endif
