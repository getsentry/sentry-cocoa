// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) @objc
public final class SentryWatchdogTerminationLogic: NSObject {

    private let options: Options
    private let activeCrashReporterState: SentryCrashReporterState
    private let isSimulatorBuild: Bool
    private let appStateManager: SentryAppStateManager

#if !SDK_V10
    @objc public convenience init(
        options: Options,
        crashAdapter: SentryCrashReporter,
        appStateManager: SentryAppStateManager
    ) {
        self.init(
            options: options,
            activeCrashReporterState: crashAdapter,
            isSimulatorBuild: crashAdapter.isSimulatorBuild,
            appStateManager: appStateManager
        )
    }
#endif // !SDK_V10

    init(
        options: Options,
        activeCrashReporterState: SentryCrashReporterState,
        isSimulatorBuild: Bool,
        appStateManager: SentryAppStateManager
    ) {
        self.options = options
        self.activeCrashReporterState = activeCrashReporterState
        self.isSimulatorBuild = isSimulatorBuild
        self.appStateManager = appStateManager
        super.init()
    }

    @objc public func isWatchdogTermination() -> Bool {
        terminatedRunAppState() != nil
    }

    /// The persisted app state of the previous run when that run ended in a watchdog termination,
    /// or `nil` when it didn't or the SDK can't tell. The caller reports the termination under the
    /// run ID of this app state, so the ID is the one the decision was based on.
    // swiftlint:disable:next cyclomatic_complexity
    func terminatedRunAppState() -> SentryAppState? {
        guard options.enableWatchdogTerminationTracking else {
            return nil
        }

        guard let previousAppState = appStateManager.loadPreviousAppState() else {
            // If there is no previous app state, we can't do anything.
            return nil
        }

        let currentAppState = appStateManager.buildCurrentAppState()

        if isSimulatorBuild {
            return nil
        }

        // If the release name is different we assume it's an upgrade
        if let currentRelease = currentAppState.releaseName,
           let previousRelease = previousAppState.releaseName,
           currentRelease != previousRelease {
            return nil
        }

        // The OS was upgraded
        if currentAppState.osVersion != previousAppState.osVersion {
            return nil
        }

        // The app may have been terminated due to device reboot
        if previousAppState.systemBootTimestamp != currentAppState.systemBootTimestamp {
            return nil
        }

        // This value can change when installing test builds using Xcode or when installing an app
        // on a device using ad-hoc distribution.
        // SentryAppState return nil id vendorId is missing when loaded from a JSON file, so
        // any case where vendorId is nil, is automatically handled
        guard let currentVendorId = currentAppState.vendorId,
              let previousVendorId = previousAppState.vendorId,
              currentVendorId == previousVendorId else {
            return nil
        }

        // Restarting the app in development is a termination we can't catch and would falsely
        // report watchdog terminations.
        if previousAppState.isDebugging {
            return nil
        }

        // The app was terminated normally
        if previousAppState.wasTerminated {
            return nil
        }

        // The app crashed on the previous run. No Watchdog Termination.
        if activeCrashReporterState.crashedLastLaunch {
            return nil
        }

        // The SDK wasn't running, so *any* crash after the SDK got closed would be seen as a Watchdog
        // Termination.
        if !previousAppState.isSDKRunning {
            return nil
        }

        // Was the app in foreground/active ?
        // If the app was in background we can't reliably tell if it was a Watchdog Termination or not.
        if !previousAppState.isActive {
            return nil
        }

        #if !SDK_V10
        // V9 reports a stored fatal app hang instead. V10 has no separate fatal app-hang path.
        if previousAppState.isANROngoing {
            return nil
        }
        #endif // !SDK_V10

        // When calling SentrySDK.start twice we would wrongly report a Watchdog Termination. We can
        // only report a Watchdog Termination when the SDK is started the first time.
        if SentrySDKInternal.startInvocations != 1 {
            return nil
        }

        return previousAppState
    }
}
#endif
// swiftlint:enable missing_docs
