@_implementationOnly import _SentryPrivate
import Foundation
import KSCrashRecording

private let appStartCrashDurationThreshold: TimeInterval = 2.0
private let appStartCrashFlushDuration: TimeInterval = 5.0

final class KSCrashReportSink: NSObject, CrashReportFilter {
    private let inAppLogic: SentryInAppLogic

    init(inAppLogic: SentryInAppLogic) {
        self.inAppLogic = inAppLogic
        super.init()
    }

    func filterReports(_ reports: [any CrashReport], onCompletion: (([any CrashReport]?, (any Error)?) -> Void)?) {
        let activeDurationSinceLastCrash = KSCrash.shared.activeDurationSinceLastCrash
        if activeDurationSinceLastCrash > 0 && activeDurationSinceLastCrash <= appStartCrashDurationThreshold {
            SentrySDKLog.warning("Startup crash: detected.")
            SentrySDKInternal.setDetectedStartUpCrash(true)
            sendReports(reports, onCompletion: onCompletion)
            SentrySDKInternal.flush(timeout: appStartCrashFlushDuration)
            SentrySDKLog.debug("Startup crash: Finished flushing.")
        } else {
            DispatchQueue.global().async { [self] in
                self.sendReports(reports, onCompletion: onCompletion)
            }
        }
    }

    private func sendReports(_ reports: [any CrashReport], onCompletion: (([any CrashReport]?, (any Error)?) -> Void)?) {
        var sentReports: [any CrashReport] = []
        for report in reports {
            guard let dictReport = report as? CrashReportDictionary else {
                SentrySDKLog.warning("KSCrashReportSink: skipping non-dictionary report of type \(type(of: report))")
                continue
            }
            let reportConverter = KSCrashReportConverter(report: dictReport, inAppLogic: inAppLogic)
            if SentrySDKInternal.currentHub().getClient() != nil {
                if let event = reportConverter.convertReportToEvent() {
                    handleConvertedEvent(event, report: report, sentReports: &sentReports)
                }
            } else {
                SentrySDKLog.error(
                    "Crash reports were found but no [SentrySDK.currentHub getClient] is set. " +
                    "Cannot send crash reports to Sentry. This is probably a misconfiguration, " +
                    "make sure you set the client with [SentrySDK.currentHub bindClient] before " +
                    "calling startCrashHandlerWithError:."
                )
            }
        }
        onCompletion?(sentReports, nil)
    }

    private func handleConvertedEvent(_ event: Event, report: any CrashReport, sentReports: inout [any CrashReport]) {
        sentReports.append(report)
        let scope = Scope(scope: SentrySDKInternal.currentHub().scope)
        SentrySDKInternal.captureFatalEvent(event, with: scope)
    }
}
