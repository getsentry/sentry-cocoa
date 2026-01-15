@_implementationOnly import _SentryPrivate

/**
 * This scope observer is used by the Watchdog Termination integration to write breadcrumbs to disk.
 * The overhead is ~0.015 seconds for 1000 breadcrumbs.
 * This class doesn't need to be thread safe as the scope already calls the scope observers in a
 * thread safe manner.
 */
class SentryWatchdogTerminationScopeObserver: NSObject, SentryScopeObserver {
    
    private let breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor
    private let attributesProcessor: SentryWatchdogTerminationAttributesProcessor

    init(breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor, attributesProcessor: SentryWatchdogTerminationAttributesProcessor) {
        self.breadcrumbProcessor = breadcrumbProcessor
        self.attributesProcessor = attributesProcessor
    }

    func setUser(_ user: User?) {
        attributesProcessor.setUser(user)
    }
    
    func setTags(_ tags: [String: String]?) {
        attributesProcessor.setTags(tags)
    }
    
    func setExtras(_ extras: [String: Any]?) {
        attributesProcessor.setExtras(extras)
    }
    
    func setContext(_ context: [String: [String: Any]]?) {
        attributesProcessor.setContext(context)
    }
    
    func setTraceContext(_ traceContext: [String: Any]?) {
        // Nothing to do here, Trace Context is not persisted for watchdog termination events
        // On regular events, we have the current trace in memory, but there isn't time to persist one
        // in watchdog termination events
    }
    
    func setDist(_ dist: String?) {
        attributesProcessor.setDist(dist)
    }
    
    func setEnvironment(_ environment: String?) {
        attributesProcessor.setEnvironment(environment)
    }
    
    func setFingerprint(_ fingerprint: [String]?) {
        attributesProcessor.setFingerprint(fingerprint)
    }
    
    func setLevel(_ level: SentryLevel) {
        // Nothing to do here, watchdog termination events are always Fatal
    }
    
    func setAttributes(_ attributes: [String: Any]?) {
        // Nothing to do here, watchdog termination events don't support attributes
    }
    
    func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {
        breadcrumbProcessor.addSerializedBreadcrumb(serializedBreadcrumb)
    }
    
    func clearBreadcrumbs() {
        breadcrumbProcessor.clearBreadcrumbs()
    }
    
    func clear() {
        breadcrumbProcessor.clear()
        attributesProcessor.clear()
    }
}
