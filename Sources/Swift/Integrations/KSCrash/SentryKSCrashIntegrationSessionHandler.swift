@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

final class SentryKSCrashIntegrationSessionHandler: NSObject {

    private let crashReporter: SentryCrashReporter
    private let dateProvider: SentryCurrentDateProvider
    private let fileManager: SentryFileManager

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private let watchdogTerminationLogic: SentryWatchdogTerminationLogic
    #endif

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    init(
        crashReporter: SentryCrashReporter,
        watchdogTerminationLogic: SentryWatchdogTerminationLogic,
        dateProvider: SentryCurrentDateProvider,
        fileManager: SentryFileManager
    ) {
        self.crashReporter = crashReporter
        self.watchdogTerminationLogic = watchdogTerminationLogic
        self.dateProvider = dateProvider
        self.fileManager = fileManager
        super.init()
    }
    #else
    init(
        crashReporter: SentryCrashReporter,
        dateProvider: SentryCurrentDateProvider,
        fileManager: SentryFileManager
    ) {
        self.crashReporter = crashReporter
        self.dateProvider = dateProvider
        self.fileManager = fileManager
        super.init()
    }
    #endif

    /**
     * When a crash or a watchdog termination happens, we end the current session as crashed, store it
     * in a dedicated location, and delete the current one. The same applies if a fatal app hang occurs.
     * Then, we end the current session as abnormal and store it in a dedicated abnormal session
     * location.
     *
     * Check out the SentryHub, which implements most of the session logic, for more details about
     * sessions.
     */
    func endCurrentSessionIfRequired() {
        guard let session = fileManager.readCurrentSession() else {
            SentrySDKLog.debug("No current session found to end.")
            return
        }

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        let shouldEndAsCrashed = crashReporter.crashedLastLaunch || watchdogTerminationLogic.isWatchdogTermination()
        #else
        let shouldEndAsCrashed = crashReporter.crashedLastLaunch
        #endif

        if shouldEndAsCrashed {
            let timeSinceLastCrash = dateProvider.date()
                .addingTimeInterval(-crashReporter.activeDurationSinceLastCrash)

            session.endCrashed(withTimestamp: timeSinceLastCrash)
            fileManager.storeCrashedSession(session)
            fileManager.deleteCurrentSession()
        } else {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            // Checking the file existence is way cheaper than reading the file and parsing its contents
            // to an Event.
            guard fileManager.appHangEventExists() else {
                SentrySDKLog.debug("No app hang event found. Won't end current session.")
                return
            }

            guard let appHangEvent = fileManager.readAppHangEvent() else {
                // Just in case the file was deleted between the check and the read.
                SentrySDKLog.warning("App hang event deleted between check and read. Cannot end current session.")
                return
            }

            session.endAbnormal(withTimestamp: appHangEvent.timestamp ?? dateProvider.date())
            fileManager.storeAbnormalSession(session)
            fileManager.deleteCurrentSession()
#endif
        }
    }
}
