internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

final class PreviousRunSessionFinalizer {

    private let crashedLastLaunch: Bool
    private let activeDurationSinceLastCrash: TimeInterval
    private let fileManager: SentryFileManager
    private let dateProvider: SentryCurrentDateProvider

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private let watchdogTerminationLogic: SentryWatchdogTerminationLogic?
    #endif

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    init(
        crashedLastLaunch: Bool,
        activeDurationSinceLastCrash: TimeInterval,
        watchdogTerminationLogic: SentryWatchdogTerminationLogic?,
        fileManager: SentryFileManager,
        dateProvider: SentryCurrentDateProvider
    ) {
        self.crashedLastLaunch = crashedLastLaunch
        self.activeDurationSinceLastCrash = activeDurationSinceLastCrash
        self.watchdogTerminationLogic = watchdogTerminationLogic
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }
    #else
    init(
        crashedLastLaunch: Bool,
        activeDurationSinceLastCrash: TimeInterval,
        fileManager: SentryFileManager,
        dateProvider: SentryCurrentDateProvider
    ) {
        self.crashedLastLaunch = crashedLastLaunch
        self.activeDurationSinceLastCrash = activeDurationSinceLastCrash
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }
    #endif

    func finalizeIfNeeded() {
        guard let session = fileManager.readCurrentSession() else {
            SentrySDKLog.debug("No current session found to end.")
            return
        }

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        let shouldEndAsCrashed = crashedLastLaunch || watchdogTerminationLogic?.isWatchdogTermination() == true
        #else
        let shouldEndAsCrashed = crashedLastLaunch
        #endif

        if shouldEndAsCrashed {
            let crashTimestamp = dateProvider.date()
                .addingTimeInterval(-activeDurationSinceLastCrash)

            session.endCrashed(withTimestamp: crashTimestamp)
            fileManager.storeCrashedSession(session)
            fileManager.deleteCurrentSession()
            return
        }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
#if !SDK_V10
        guard fileManager.appHangEventExists() else {
            SentrySDKLog.debug("No app hang event found. Won't end current session.")
            return
        }

        guard let appHangEvent = fileManager.readAppHangEvent() else {
            SentrySDKLog.warning("App hang event deleted between check and read. Cannot end current session.")
            return
        }

        session.endAbnormal(withTimestamp: appHangEvent.timestamp ?? Date())
        fileManager.storeAbnormalSession(session)
        fileManager.deleteCurrentSession()
#endif // !SDK_V10
#endif
    }
}
