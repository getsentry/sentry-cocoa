// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
@_spi(Private) @objc
public final class SentryWatchdogTerminationLogic: NSObject {

    private let options: Options
    private let crashAdapter: SentryCrashWrapper
    private let appStateManager: SentryAppStateManager

    @objc public init(options: Options, crashAdapter: SentryCrashWrapper, appStateManager: SentryAppStateManager) {
        self.options = options
        self.crashAdapter = crashAdapter
        self.appStateManager = appStateManager
        super.init()
    }

    // swiftlint:disable:next cyclomatic_complexity
    @objc public func isWatchdogTermination() -> Bool {
        guard options.enableWatchdogTerminationTracking else {
            return false
        }

        guard let previousAppState = appStateManager.loadPreviousAppState() else {
            // If there is no previous app state, we can't do anything.
            return false
        }

        let currentAppState = appStateManager.buildCurrentAppState()

        if crashAdapter.isSimulatorBuild {
            return false
        }

        // If the release name is different we assume it's an upgrade
        if let currentRelease = currentAppState.releaseName,
           let previousRelease = previousAppState.releaseName,
           currentRelease != previousRelease {
            return false
        }

        // The OS was upgraded
        if currentAppState.osVersion != previousAppState.osVersion {
            return false
        }

        // The app may have been terminated due to device reboot
        if previousAppState.systemBootTimestamp != currentAppState.systemBootTimestamp {
            return false
        }

        // This value can change when installing test builds using Xcode or when installing an app
        // on a device using ad-hoc distribution.
        // SentryAppState return nil id vendorId is missing when loaded from a JSON file, so
        // any case where vendorId is nil, is automatically handled
        guard let currentVendorId = currentAppState.vendorId,
              let previousVendorId = previousAppState.vendorId,
              currentVendorId == previousVendorId else {
            return false
        }

        // Restarting the app in development is a termination we can't catch and would falsely
        // report watchdog terminations.
        if previousAppState.isDebugging {
            return false
        }

        // The app was terminated normally
        if previousAppState.wasTerminated {
            return false
        }

        // The app crashed on the previous run. No Watchdog Termination.
        if crashAdapter.crashedLastLaunch {
            return false
        }

        // The SDK wasn't running, so *any* crash after the SDK got closed would be seen as a Watchdog
        // Termination.
        if !previousAppState.isSDKRunning {
            return false
        }

        // Was the app in foreground/active ?
        // If the app was in background we can't reliably tell if it was a Watchdog Termination or not.
        if !previousAppState.isActive {
            return false
        }

        if previousAppState.isANROngoing {
            return false
        }

        // When calling SentrySDK.start twice we would wrongly report a Watchdog Termination. We can
        // only report a Watchdog Termination when the SDK is started the first time.
        if SentrySDKInternal.startInvocations != 1 {
            return false
        }

        return true
    }
}
#endif
// swiftlint:enable missing_docs
