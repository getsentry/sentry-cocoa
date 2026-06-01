@_implementationOnly import _SentryPrivate
import Foundation
import KSCrashInstallations

/**
 * Crash installation reporter that wires the KSCrash filter pipeline to Sentry.
 *
 * This class extends @c KSCrashInstallation (upstream KSCrash v2) to provide
 * Sentry-specific crash report processing through a @c KSCrashReportSink.
 */
final class SentryKSCrashInstallationReporter: CrashInstallation {
    private let inAppLogic: SentryInAppLogic
    private let reportSink: KSCrashReportSink

    init(inAppLogic: SentryInAppLogic) {
        self.inAppLogic = inAppLogic
        self.reportSink = KSCrashReportSink(inAppLogic: inAppLogic)
        super.init()
    }

    override func sink() -> any CrashReportFilter {
        reportSink
    }
}
