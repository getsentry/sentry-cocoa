@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

typealias WatchdogTerminationTrackingProvider = ANRTrackerBuilder & ProcessInfoProvider & HangTrackerProvider & AppStateManagerProvider & WatchdogTerminationScopeObserverBuilder & WatchdogTerminationTrackerBuilder

final class SentryWatchdogTerminationTrackingIntegration<Dependencies: WatchdogTerminationTrackingProvider>: NSObject, SwiftIntegration, SentryANRTrackerDelegate {

    private let tracker: SentryWatchdogTerminationTracker
    private let timeoutInterval: TimeInterval
    private let anrTracker: SentryANRTracker?
    private let hangTracker: HangTracker?
    private let appStateManager: SentryAppStateManager
    
    private var hasStartedHang: Bool = false
    private var callbackId: UUID?

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
        timeoutInterval = options.appHangTimeoutInterval
        if options.experimental.enableWatchdogTerminationsV2 {
            hangTracker = dependencies.hangTracker
            anrTracker = nil
        } else {
            anrTracker = dependencies.getANRTracker(options.appHangTimeoutInterval)
            hangTracker = nil
        }
        appStateManager = dependencies.appStateManager

        super.init()

        tracker.start()
        callbackId = hangTracker?.addOngoingHangObserver { [weak self] interval, ongoing in
            guard let self, interval > timeoutInterval else {
                return
            }

            if ongoing {
                hangStarted()
            } else {
                hangStopped()
            }
        }
        anrTracker?.add(listener: self)

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
        anrTracker?.remove(listener: self)
        
        guard let callbackId else {
            return
        }
        hangTracker?.removeObserver(id: callbackId)
    }

    func hangStarted() {
        guard !hasStartedHang else { return }

        hasStartedHang = true
        appStateManager.updateAppState { appState in
            appState.isANROngoing = true
        }
    }

    func hangStopped() {
        hasStartedHang = false
        appStateManager.updateAppState { appState in
            appState.isANROngoing = false
        }
    }

    // MARK: SentryANRTrackerDelegate
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
