@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

@objc
final class SentryCrashIntegrationSessionHandler: NSObject {

    private let crashWrapper: SentryCrashWrapper
    private let fileManager: SentryFileManager

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    private let watchdogTerminationLogic: SentryWatchdogTerminationLogic
    #endif

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    @objc public init(
        crashWrapper: SentryCrashWrapper,
        watchdogTerminationLogic: SentryWatchdogTerminationLogic,
        fileManager: SentryFileManager
    ) {
        self.crashWrapper = crashWrapper
        self.watchdogTerminationLogic = watchdogTerminationLogic
        self.fileManager = fileManager
        super.init()
    }
    #else
    @objc public init(crashWrapper: SentryCrashWrapper, fileManager: SentryFileManager) {
        self.crashWrapper = crashWrapper
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
    @objc public func endCurrentSessionIfRequired() {
        guard let session = fileManager.readCurrentSession() else {
            SentrySDKLog.debug("No current session found to end.")
            return
        }

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        let shouldEndAsCrashed = crashWrapper.crashedLastLaunch || watchdogTerminationLogic.isWatchdogTermination()
        #else
        let shouldEndAsCrashed = crashWrapper.crashedLastLaunch
        #endif

        if shouldEndAsCrashed {
            let timeSinceLastCrash = SentryDependencyContainer.sharedInstance().dateProvider.date()
                .addingTimeInterval(-crashWrapper.activeDurationSinceLastCrash)

            session.endCrashed(withTimestamp: timeSinceLastCrash)
            fileManager.storeCrashedSession(session)
            fileManager.deleteCurrentSession()
        } else {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
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

            session.endAbnormal(withTimestamp: appHangEvent.timestamp ?? Date())
            fileManager.storeAbnormalSession(session)
            fileManager.deleteCurrentSession()
#endif
        }
        
    }
}
