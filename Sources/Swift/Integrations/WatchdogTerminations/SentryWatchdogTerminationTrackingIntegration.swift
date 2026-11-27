// swiftlint:disable function_body_length
internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

typealias WatchdogTerminationTrackingProvider = ProcessInfoProvider & WatchdogTerminationTrackerBuilder & ExtensionDetectorProvider & WatchdogTerminationAttributesProcessorProvider & WatchdogTerminationBreadcrumbProcessorProvider
protocol WatchdogTerminationTrackingIntegrationANRSupport { }

final class SentryWatchdogTerminationTrackingIntegration<Dependencies: WatchdogTerminationTrackingProvider>: NSObject, SwiftIntegration, WatchdogTerminationTrackingIntegrationANRSupport {

    private let tracker: SentryWatchdogTerminationTracker
    private let breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor

    // swiftlint:disable:next function_body_length
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
        guard let breadcrumbProcessor = dependencies.getWatchdogTerminationBreadcrumbProcessor(options) else {
            SentrySDKLog.fatal("Watchdog Termination breadcrumb processor not available")
            return nil
        }

        tracker = terminationTracker
        self.breadcrumbProcessor = breadcrumbProcessor

        super.init()

        tracker.start()

        let scopeObserver = SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: breadcrumbProcessor,
            attributesProcessor: dependencies.watchdogTerminationAttributesProcessor
        )
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
        breadcrumbProcessor.flushAndClose()

    }

}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable function_body_length
