@_implementationOnly import _SentryPrivate
import Foundation
@_implementationOnly import KSCrashInstallations

/**
 * Crash installation reporter that wires the KSCrash filter pipeline to Sentry.
 *
 * This class extends @c KSCrashInstallation (upstream KSCrash v2) to provide
 * Sentry-specific crash report processing through a @c KSCrashReportSink.
 */
final class SentryKSCrashInstallationReporter: CrashInstallation {
    private let inAppLogic: SentryInAppLogic

    init(inAppLogic: SentryInAppLogic) {
        self.inAppLogic = inAppLogic
        super.init()
    }

    override func sink() -> any CrashReportFilter {
        KSCrashReportSink(inAppLogic: inAppLogic)
    }
}
