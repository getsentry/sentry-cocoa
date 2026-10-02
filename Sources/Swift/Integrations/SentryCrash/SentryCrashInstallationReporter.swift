#if !SDK_V10
internal import _SentryPrivate
import Foundation

/**
 * Crash installation reporter that handles Sentry-specific reporting details.
 *
 * This class extends SentryCrashInstallation to provide Sentry-specific crash report
 * processing through a SentryCrashReportSink.
 */
final class SentryCrashInstallationReporter: SentryCrashInstallation {

    private let inAppLogic: SentryInAppLogic
    private let crashWrapper: SentryCrashReporter
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let startupCrashFlush: SentryStartupCrashFlush

    init(
        inAppLogic: SentryInAppLogic,
        crashWrapper: SentryCrashReporter,
        dispatchQueue: SentryDispatchQueueWrapper,
        startupCrashFlush: SentryStartupCrashFlush
    ) {
        self.inAppLogic = inAppLogic
        self.crashWrapper = crashWrapper
        self.dispatchQueue = dispatchQueue
        self.startupCrashFlush = startupCrashFlush
        super.init(requiredProperties: [])
    }

    override func sink() -> (any SentryCrashReportFilter)? {
        return SentryCrashReportSink(
            inAppLogic: inAppLogic,
            crashWrapper: crashWrapper,
            dispatchQueue: dispatchQueue,
            startupCrashFlush: startupCrashFlush
        )
    }

    override func sendAllReports(completion onCompletion: SentryCrashReportFilterCompletion?) {
        super.sendAllReports { filteredReports, completed, error in
            if let error = error {
                SentrySDKLog.error("Error sending crash reports: \(error.localizedDescription)")
            }
            SentrySDKLog.debug("Sent \(String(describing: filteredReports?.count)) crash report(s)")
            if completed, let onCompletion = onCompletion {
                onCompletion(filteredReports, completed, error)
            }
        }
    }
}
#endif // !SDK_V10
