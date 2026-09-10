#if SDK_V10
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
    /// - Captured report: return `.success` containing the report; KSCrash deletes it.
    /// - Unsupported or permanently invalid report: return `.success` with no reports; KSCrash
    ///   consumes it so it cannot permanently block delivery.
    /// - Retryable failure: return `.failure`; KSCrash retains the report for a later launch.
    final class ReportFilterCore {
        private static let startupCrashDurationThreshold: TimeInterval = 2
        private static let nanosecondsPerSecond: TimeInterval = 1_000_000_000
        private static let errorDomain = "io.sentry.kscrash-report-filter"

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
            onCompletion: ((Result<[Report], Error>) -> Void)? = nil
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
                onCompletion?(.failure(error))
                return
            }
            guard let report = reports.first else {
                onCompletion?(.success([]))
                return
            }

            let operation = processingSession.register {
                onCompletion?(.failure(ReportProcessingSession.cancellationError))
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
            onCompletion: ((Result<[Report], Error>) -> Void)?
        ) {
            guard operation.beginProcessing() else {
                return
            }
            SentrySDKLog.warning("Startup crash detected.")
            SentrySDKInternal.setDetectedStartUpCrash(true)
            let result = Self.processReport(
                report,
                reportDictionary: reportDictionary,
                reportProcessor: reportProcessor,
                operation: operation
            )
            operation.complete {
                onCompletion?(result)
            }
        }

        private func processRegularReport<Report>(
            _ report: Report,
            reportDictionary: @escaping (Report) -> [AnyHashable: Any]?,
            operation: ReportProcessingSession.Operation,
            onCompletion: ((Result<[Report], Error>) -> Void)?
        ) {
            dispatchQueue.dispatchAsync { [reportProcessor] in
                guard operation.beginProcessing() else {
                    return
                }
                let result = Self.processReport(
                    report,
                    reportDictionary: reportDictionary,
                    reportProcessor: reportProcessor,
                    operation: operation
                )
                operation.complete {
                    onCompletion?(result)
                }
            }
        }

        private static func processReport<Report>(
            _ report: Report,
            reportDictionary: (Report) -> [AnyHashable: Any]?,
            reportProcessor: any StoredCrashReportProcessing,
            operation: ReportProcessingSession.Operation
        ) -> Result<[Report], Error> {
            guard let dictionary = reportDictionary(report) else {
                SentrySDKLog.error("Discarding unsupported KSCrash report type.")
                return .success([])
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
                return .success([report])
            } catch {
                guard isPermanentProcessingError(error) else {
                    SentrySDKLog.warning(
                        "Deferring KSCrash report processing after retryable error: \(error.localizedDescription)"
                    )
                    return .failure(error)
                }
                SentrySDKLog.error(
                    "Discarding unprocessable KSCrash report: \(error.localizedDescription)"
                )
                return .success([])
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
            guard
                let reportContext = report["report"] as? [AnyHashable: Any],
                let systemContext = report["system"] as? [AnyHashable: Any],
                let crashDate = date(from: reportContext["timestamp"]),
                let crashHandlerInitDate = crashHandlerInitializationDate(from: systemContext)
            else {
                return nil
            }

            return crashDate.timeIntervalSince(crashHandlerInitDate)
        }

        private static func crashHandlerInitializationDate(
            from systemContext: [AnyHashable: Any]
        ) -> Date? {
            // KSCrash samples this wall-clock value alongside app_start_time, but preserves
            // nanosecond rather than whole-second precision. Older reports may not contain it.
            if let wallClockNanoseconds = systemContext["process_start_wall_clock_ns"] as? NSNumber {
                let timestamp = wallClockNanoseconds.doubleValue / nanosecondsPerSecond
                if timestamp.isFinite && timestamp >= 0 {
                    return Date(timeIntervalSince1970: timestamp)
                }
            }

            // Despite the field name, KSCrash records app_start_time when its System monitor
            // initializes. Keep it as a compatibility fallback for older or malformed reports.
            return date(from: systemContext["app_start_time"])
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
