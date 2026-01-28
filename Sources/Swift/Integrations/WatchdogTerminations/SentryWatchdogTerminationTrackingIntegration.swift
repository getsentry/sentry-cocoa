@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst) || os(visionOS)) && !SENTRY_NO_UIKIT

typealias WatchdogTerminationTrackingProvider = ProcessInfoProvider & AppStateManagerProvider & WatchdogTerminationScopeObserverBuilder & WatchdogTerminationTrackerBuilder & WatchdogTerminationHangTrackerBuilder

final class SentryWatchdogTerminationTrackingIntegration<Dependencies: WatchdogTerminationTrackingProvider>: NSObject, SwiftIntegration {

    private let appStateManager: SentryAppStateManager
    private let terminationTracker: SentryWatchdogTerminationTracker
    private let hangTracker: SentryWatchdogTerminationHangTracker

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableWatchdogTerminationTracking else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableWatchdogTerminationTracking is disabled.")
            return nil
        }
        guard options.enableCrashHandler else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }
        guard dependencies.processInfoWrapper.environment["XCTestConfigurationFilePath"] == nil else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because XCTestConfigurationFilePath is set.")
            return nil
        }
        guard let terminationTracker = dependencies.getWatchdogTerminationTracker(options) else {
            SentrySDKLog.fatal("Watchdog Termination tracker not available")
            return nil
        }
        self.terminationTracker = terminationTracker

        appStateManager = dependencies.appStateManager
        guard let hangTracker = dependencies.getWatchdogTerminationHangTracker(
            timeoutInterval: options.appHangTimeoutInterval,
            hangStarted: { [weak appStateManager] in
                SentrySDKLog.debug("App hang detected in watchdog termination tracking")
                appStateManager?.updateAppState { appState in
                    appState.isANROngoing = true
                }
            },
            hangStopped: { [weak appStateManager] in
                appStateManager?.updateAppState { appState in
                    appState.isANROngoing = false
                }
            }
        ) else {
            SentrySDKLog.fatal("Watchdog Termination tracker not available")
            return nil
        }
        self.hangTracker = hangTracker

        super.init()

        terminationTracker.start()
        hangTracker.start()

        let scopeObserver = dependencies.getWatchdogTerminationScopeObserverWithOptions(options)
        SentrySDKInternal.currentHub().configureScope { outerScope in
            // Add the observer to the scope so that it can be notified when the scope changes.
            outerScope.add(scopeObserver)

            // Sync the current context to the observer to capture context modifications that happened
            // before installation.
            scopeObserver.setContext(outerScope.contextDictionary as? [String: [String: Any]])
            scopeObserver.setUser(outerScope.userObject)
            scopeObserver.setEnvironment(outerScope.environmentString)
            scopeObserver.setDist(outerScope.distString)
            scopeObserver.setTags(outerScope.tags)
            scopeObserver.setExtras(outerScope.extraDictionary as? [String: Any])
            scopeObserver.setFingerprint(outerScope.fingerprintArray as? [String])
            // We intentionally skip calling `setTraceContext:` since traces are not stored for watchdog
            // termination events
            // We intentionally skip calling `setLevel:` since all termination events have fatal level
        }
    }

    static var name: String {
        "SentryWatchdogTerminationTrackingIntegration"
    }

    func uninstall() {
        terminationTracker.stop()
        hangTracker.stop()
    }
}

#endif // (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst) || os(visionOS)) && !SENTRY_NO_UIKIT
