@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

typealias WatchdogTerminationTrackingProvider = ProcessInfoProvider & AppHangTrackerProvider & AppStateManagerProvider & WatchdogTerminationScopeObserverBuilder & WatchdogTerminationTrackerBuilder & ExtensionDetectorProvider

final class SentryWatchdogTerminationTrackingIntegration<Dependencies: WatchdogTerminationTrackingProvider>: NSObject, SwiftIntegration {

    private let tracker: SentryWatchdogTerminationTracker
    private let timeoutInterval: TimeInterval
    private let appHangTracker: SentryAppHangTracker
    private let appStateManager: SentryAppStateManager

    private var hasStartedHang: Bool = false
    private var appHangTrackerObserverToken: SentryAppHangTrackerObserverToken?

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

        if let identifier = dependencies.extensionDetector.getExtensionPointIdentifier(), identifier.isDisabledExtensionPointIdentifier {
            SentrySDKLog.debug("Not enabling watchdog termination tracking for extension: \(identifier)")
            return nil
        }

        guard let terminationTracker = dependencies.getWatchdogTerminationTracker(options) else {
            SentrySDKLog.fatal("Watchdog Termination tracker not available")
            return nil
        }

        tracker = terminationTracker
        timeoutInterval = options.appHangTimeoutInterval
        appHangTracker = dependencies.appHangTracker
        appStateManager = dependencies.appStateManager

        super.init()

        tracker.start()
        appHangTrackerObserverToken = appHangTracker.addObserver(threshold: timeoutInterval) { [weak self] hang in
            guard let self else { return }

            switch hang.state {
            case .started:
                hangStarted()
            case .ended:
                hangStopped()
            }
        }

        let scopeObserver = dependencies.getWatchdogTerminationScopeObserverWithOptions(options)
        SentrySDKInternal.currentHub().configureScope { outerScope in
            Self.syncWatchdogScopeObserver(scopeObserver, from: outerScope)
        }
    }

    private static func syncWatchdogScopeObserver(_ scopeObserver: SentryScopeObserver, from outerScope: Scope) {
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

    static var name: String {
        "SentryWatchdogTerminationTrackingIntegration"
    }

    func uninstall() {
        tracker.stop()
        if let token = appHangTrackerObserverToken {
            appHangTracker.removeObserver(token: token)
        }
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

}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
