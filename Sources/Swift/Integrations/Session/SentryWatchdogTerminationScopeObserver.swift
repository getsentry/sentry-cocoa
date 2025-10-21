@_implementationOnly import _SentryPrivate

/**
 * This scope observer is used by the Watchdog Termination integration to write breadcrumbs to disk.
 * The overhead is ~0.015 seconds for 1000 breadcrumbs.
 * This class doesn't need to be thread safe as the scope already calls the scope observers in a
 * thread safe manner.
 */
@_spi(Private) @objc public class SentryWatchdogTerminationScopeObserver: NSObject, SentryScopeObserver {
    
    private let breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor
    private let attributesProcessor: SentryWatchdogTerminationAttributesProcessor
    
    init(breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor, attributesProcessor: SentryWatchdogTerminationAttributesProcessor) {
        self.breadcrumbProcessor = breadcrumbProcessor
        self.attributesProcessor = attributesProcessor
    }

    @objc public convenience init(maxBreadcrumbs: Int, attributesProcessor: SentryWatchdogTerminationAttributesProcessor) {
        self.init(breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor(maxBreadcrumbs: maxBreadcrumbs), attributesProcessor: attributesProcessor)
    }

    public func setUser(_ user: User?) {
        attributesProcessor.setUser(user)
    }
    
    public func setTags(_ tags: [String: String]?) {
        attributesProcessor.setTags(tags)
    }
    
    public func setExtras(_ extras: [String: Any]?) {
        attributesProcessor.setExtras(extras)
    }
    
    public func setContext(_ context: [String: [String: Any]]?) {
        attributesProcessor.setContext(context)
    }
    
    public func setTraceContext(_ traceContext: [String: Any]?) {
        // Nothing to do here, Trace Context is not persisted for watchdog termination events
        // On regular events, we have the current trace in memory, but there isn't time to persist one
        // in watchdog termination events
    }
    
    public func setDist(_ dist: String?) {
        attributesProcessor.setDist(dist)
    }
    
    public func setEnvironment(_ environment: String?) {
        attributesProcessor.setEnvironment(environment)
    }
    
    public func setFingerprint(_ fingerprint: [String]?) {
        attributesProcessor.setFingerprint(fingerprint)
    }
    
    public func setLevel(_ level: SentryLevel) {
        // Nothing to do here, watchdog termination events are always Fatal
    }
    
    public func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {
        breadcrumbProcessor.addSerializedBreadcrumb(serializedBreadcrumb)
    }
    
    public func clearBreadcrumbs() {
        breadcrumbProcessor.clearBreadcrumbs()
    }
    
    public func clear() {
        breadcrumbProcessor.clear()
        attributesProcessor.clear()
    }
}
