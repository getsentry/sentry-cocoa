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
        private static let startupCrashDurationThreshold: TimeInterval = 2
        private static let startupCrashFlushDuration: TimeInterval = 5

        private struct ProcessingResult<Report> {
            let processedReports: [Report]
            let retryableError: (any Error)?
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
            let isStartupCrash = reports.contains { report in
                guard let dictionary = reportDictionary(report) else {
                    return false
                }
                return Self.isStartupCrash(dictionary)
            }

            if isStartupCrash {
                SentrySDKLog.warning("Startup crash detected.")
                SentrySDKInternal.setDetectedStartUpCrash(true)
                let result = Self.processReports(
                    reports,
                    reportDictionary: reportDictionary,
                    reportProcessor: reportProcessor
                )
                SentrySDKInternal.flush(timeout: Self.startupCrashFlushDuration)
                onCompletion?(result.processedReports, result.retryableError)
                return
            }

            dispatchQueue.dispatchAsync { [reportProcessor = self.reportProcessor] in
                let result = Self.processReports(
                    reports,
                    reportDictionary: reportDictionary,
                    reportProcessor: reportProcessor
                )
                onCompletion?(result.processedReports, result.retryableError)
            }
        }

        private static func processReports<Report>(
            _ reports: [Report],
            reportDictionary: (Report) -> [AnyHashable: Any]?,
            reportProcessor: SentryStoredCrashReportProcessor
        ) -> ProcessingResult<Report> {
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
                    guard isPermanentProcessingError(error) else {
                        SentrySDKLog.warning(
                            "Deferring KSCrash report processing after retryable error: \(error.localizedDescription)"
                        )
                        return ProcessingResult(
                            processedReports: processedReports,
                            retryableError: error
                        )
                    }
                    SentrySDKLog.error(
                        "Discarding unprocessable KSCrash report: \(error.localizedDescription)"
                    )
                }
            }

            // ReportStore's .onSuccess cleanup policy deletes the whole attempted batch only when
            // the completion error is nil. Consume permanently invalid reports so they cannot block
            // later valid reports, but return retryable errors so the entire batch remains on disk.
            return ProcessingResult(processedReports: processedReports, retryableError: nil)
        }

        private static func isPermanentProcessingError(_ error: any Error) -> Bool {
            let error = error as NSError
            guard error.domain == SentryStoredCrashReportProcessorErrorDomain else {
                return false
            }
            return error.code == SentryStoredCrashReportProcessorError.unsupportedReport.rawValue
                || error.code == SentryStoredCrashReportProcessorError.conversionFailed.rawValue
        }

        private static func isStartupCrash(_ report: [AnyHashable: Any]) -> Bool {
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
