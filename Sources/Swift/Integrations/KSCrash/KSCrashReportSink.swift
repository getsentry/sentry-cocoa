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

            guard SentrySDKInternal.currentHub().getClient() != nil else {
                SentrySDKLog.error(
                    "Crash reports were found but no [SentrySDK.currentHub getClient] is set. " +
                    "Cannot send crash reports to Sentry. This is probably a misconfiguration, " +
                    "make sure you set the client with [SentrySDK.currentHub bindClient] before " +
                    "calling startCrashHandlerWithError:."
                )

                continue
            }

            let converter = KSCrashReportConverter(report: dictReport, inAppLogic: inAppLogic)

            guard let event = converter.convertReportToEvent() else {
                continue
            }

            handleConvertedEvent(event, report: dictReport, sentReports: &sentReports)
        }

        onCompletion?(sentReports, nil)
    }

    private func handleConvertedEvent(
        _ event: Event,
        report: CrashReportDictionary,
        sentReports: inout [any CrashReport]
    ) {
        sentReports.append(report)
        let scope = SentrySDKInternal.currentHub().scope

        if let attachments = report.value["attachments"] as? [String] {
            for attachment in attachments {
                scope.addCrashReportAttachment(inPath: attachment)
            }
        }

        SentrySDKInternal.captureFatalEvent(event, with: scope)
    }
}
