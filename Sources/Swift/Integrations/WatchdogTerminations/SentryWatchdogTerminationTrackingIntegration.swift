@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

typealias WatchdogTerminationTrackingProvider = ANRTrackerBuilder & ProcessInfoProvider & AppStateManagerProvider & WatchdogTerminationScopeObserverBuilder & WatchdogTerminationTrackerBuilder & WatchdogTerminationHangTrackerBuilder

final class SentryWatchdogTerminationTrackingIntegration<Dependencies: WatchdogTerminationTrackingProvider>: NSObject, SwiftIntegration, SentryANRTrackerDelegate {

    private let tracker: SentryWatchdogTerminationTracker
    private let appStateManager: SentryAppStateManager

    /// The old ANR tracker used when `enableWatchdogTerminationRunLoopHangTracker` is disabled.
    private let anrTracker: SentryANRTracker?

    /// The new run loop-based hang tracker used when `enableWatchdogTerminationRunLoopHangTracker` is enabled.
    private let hangTracker: SentryWatchdogTerminationHangTracker?

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

        tracker = terminationTracker
        appStateManager = dependencies.appStateManager

        if options.experimental.enableWatchdogTerminationRunLoopHangTracker {
            guard let hangTracker = dependencies.getWatchdogTerminationHangTracker(timeoutInterval: options.appHangTimeoutInterval) else {
                SentrySDKLog.fatal("Watchdog Termination hang tracker not available")
                return nil
            }
            self.hangTracker = hangTracker
            self.anrTracker = nil
        } else {
            self.anrTracker = dependencies.getANRTracker(options.appHangTimeoutInterval)
            self.hangTracker = nil
        }

        super.init()

        tracker.start()

        if let hangTracker = hangTracker {
            hangTracker.start()
        } else if let anrTracker = anrTracker {
            anrTracker.add(listener: self)
        }

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
        tracker.stop()
        if let hangTracker = hangTracker {
            hangTracker.stop()
        } else if let anrTracker = anrTracker {
            anrTracker.remove(listener: self)
        }
    }

    // MARK: - SentryANRTrackerDelegate

    func anrDetected(type: SentryANRType) {
        appStateManager.updateAppState { appState in
            appState.isANROngoing = true
        }
    }

    func anrStopped(result: SentryANRStoppedResult?) {
        appStateManager.updateAppState { appState in
            appState.isANROngoing = false
        }
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
