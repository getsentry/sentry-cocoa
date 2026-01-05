@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
/**
 * Detect watchdog terminations based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a watchdog
 * termination is detected, the SDK sends it as crash event. Only works for iOS, tvOS and
 * macCatalyst.
 */
@_spi(Private) @objc public
final class SentryWatchdogTerminationTracker: NSObject {
    
    @objc public static let SentryWatchdogTerminationExceptionType: String = "WatchdogTermination"
    @objc public static let SentryWatchdogTerminationExceptionValue: String = "The OS watchdog terminated your app, possibly because it overused RAM."
    @objc public static let SentryWatchdogTerminationMechanismType: String = "watchdog_termination"

    private let options: Options
    private let watchdogTerminationLogic: SentryWatchdogTerminationLogic
    private let appStateManager: SentryAppStateManager
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let fileManager: SentryFileManager
    private let scopePersistentStore: SentryScopePersistentStore

    @objc public init(options: Options,
                      watchdogTerminationLogic: SentryWatchdogTerminationLogic,
                      appStateManager: SentryAppStateManager,
                      dispatchQueueWrapper: SentryDispatchQueueWrapper,
                      fileManager: SentryFileManager,
                      scopePersistentStore: SentryScopePersistentStore) {
        self.options = options
        self.watchdogTerminationLogic = watchdogTerminationLogic
        self.appStateManager = appStateManager
        self.dispatchQueue = dispatchQueueWrapper
        self.fileManager = fileManager
        self.scopePersistentStore = scopePersistentStore
    }

    @objc public func start() {
        appStateManager.start()

        dispatchQueue.dispatchAsync {
            guard self.watchdogTerminationLogic.isWatchdogTermination() else {
                return
            }

            let event = Event(level: .fatal)

            self.addBreadcrumbs(to: event)
            self.addContext(to: event)
            event.user = self.scopePersistentStore.readPreviousUserFromDisk()
            event.dist = self.scopePersistentStore.readPreviousDistFromDisk()
            event.environment = self.scopePersistentStore.readPreviousEnvironmentFromDisk()
            event.tags = self.scopePersistentStore.readPreviousTagsFromDisk()
            event.extra = self.scopePersistentStore.readPreviousExtrasFromDisk()
            event.fingerprint = self.scopePersistentStore.readPreviousFingerprintFromDisk()
            // Termination events always have fatal level, so we are not reading from disk

            let exception = Exception(
                value: SentryWatchdogTerminationTracker.SentryWatchdogTerminationExceptionValue,
                type: SentryWatchdogTerminationTracker.SentryWatchdogTerminationExceptionType)
            let mechanism = Mechanism(type: SentryWatchdogTerminationTracker.SentryWatchdogTerminationMechanismType)
            mechanism.handled = false
            exception.mechanism = mechanism
            event.exceptions = [exception]

            // We don't need to update the releaseName of the event to the previous app state as we
            // assume it's not a watchdog termination when the releaseName changed between app
            // starts.
            SentrySDKInternal.captureFatalEvent(event)
        }
    }

    private func addBreadcrumbs(to event: Event) {
        // Set to empty list so no breadcrumbs of the current scope are added
        event.breadcrumbs = []

        // Load the previous breadcrumbs from disk, which are already serialized
        var serializedBreadcrumbs = fileManager.readPreviousBreadcrumbs()
        if serializedBreadcrumbs.count > options.maxBreadcrumbs {
            let start = serializedBreadcrumbs.count - Int(options.maxBreadcrumbs)
            serializedBreadcrumbs = Array(serializedBreadcrumbs[start...])
        }
        event.serializedBreadcrumbs = serializedBreadcrumbs

        if let lastBreadcrumb = serializedBreadcrumbs.last as? [String: Any],
          let timestampString = lastBreadcrumb["timestamp"] as? String {
           event.timestamp = sentry_fromIso8601String(timestampString)
       }
    }

    private func addContext(to event: Event) {
        // Load the previous context from disk, or create an empty one if it doesn't exist
        let previousContext = scopePersistentStore.readPreviousContextFromDisk() ?? [:]
        var context = previousContext

        // We only report watchdog terminations if the app was in the foreground. So, we can
        // already set it. We can't set it in the client because the client uses the current
        // application state, and the app could be in the background when executing this code.
        var appContext = (event.context?["app"] as? [String: Any]) ?? [:]
        appContext["in_foreground"] = true
        context["app"] = appContext

        event.context = context
    }

    @objc public func stop() {
        appStateManager.stop()
    }
}
#endif
