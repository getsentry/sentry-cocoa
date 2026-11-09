internal import _SentryPrivate
import Foundation

/// The scope holds useful information that should be sent along with the event.
/// For instance tags or breadcrumbs are stored on the scope.
///
/// See https://docs.sentry.io/platforms/apple/enriching-events/scopes/#whats-a-scope-whats-a-hub
@objc(SentryScope)
open class Scope: NSObject {
    let spanLock = NSObject()
    let observersLock = NSObject()
    private let propagationContextLock = NSObject()
    /// Guards dist, environment, and level. These were atomic properties, so readers and writers
    /// share one lock. `userObject` stays on `synchronized(self)` with `setUser`.
    private let metadataLock = NSObject()

    var spanStorage: Span?
    private var propagationContextStorage: SentryPropagationContext
    private var currentScreenStorage: String?
    var observers: [AnyObject] = []

    /// Maximum number of breadcrumbs retained by this scope.
    /// Internal storage. The test category redeclares it; production code uses the initializer.
    @objc var maxBreadcrumbs: UInt
    var currentBreadcrumbIndex = 0

    /// Breadcrumbs in ring-buffer order. Tests and equality read this storage directly.
    /// The array object is the lock. Do not replace it after the scope is shared.
    @objc var breadcrumbArray: NSMutableArray

    /// Tags stored on the scope. Mutators lock this dictionary.
    @_spi(Private) @objc public var tagDictionary: NSMutableDictionary

    /// Extras stored on the scope. Mutators lock this dictionary.
    @_spi(Private) @objc public var extraDictionary: NSMutableDictionary

    /// Context stored on the scope. Mutators lock this dictionary.
    @_spi(Private) @objc public var contextDictionary: NSMutableDictionary

    /// User stored on the scope. `setUser` is what notifies observers.
    /// Reads and writes take `synchronized(self)`, the same lock as `setUser`.
    @_spi(Private) @objc public var userObject: User? {
        get { synchronized(self) { userObjectStorage } }
        set { synchronized(self) { userObjectStorage = newValue } }
    }

    private var userObjectStorage: User?

    /// True after an explicit user change. Copies keep this flag and do not inherit the callback.
    var userWasSet = false
    var userPersistenceCallback: ((User?) -> Void)?

    /// Distribution stored on the scope.
    @_spi(Private) @objc public var distString: String? {
        get { synchronized(metadataLock) { distStringStorage } }
        set { synchronized(metadataLock) { distStringStorage = newValue } }
    }

    private var distStringStorage: String?

    /// Environment stored on the scope.
    @_spi(Private) @objc public var environmentString: String? {
        get { synchronized(metadataLock) { environmentStringStorage } }
        set { synchronized(metadataLock) { environmentStringStorage = newValue } }
    }

    private var environmentStringStorage: String?

    /// Fingerprints stored on the scope. Mutators lock this array.
    @_spi(Private) @objc public var fingerprintArray: NSMutableArray

    /// Level stored on the scope.
    @_spi(Private) @objc public var levelEnum: SentryLevel {
        get { synchronized(metadataLock) { levelEnumStorage } }
        set { synchronized(metadataLock) { levelEnumStorage = newValue } }
    }

    private var levelEnumStorage: SentryLevel = .none

    /// Attachments stored on the scope. Mutators lock this array.
    /// The array object is the lock. Do not replace it after the scope is shared.
    @objc var attachmentArray: NSMutableArray

    var crashReportAttachmentArray: NSMutableArray
    var attributesDictionary: NSMutableDictionary

    /// Feature-flag buffer owned by this scope.
    @_spi(Private) @objc public private(set) var featureFlagBuffer: SentryFeatureFlagBufferWrapper

    /// Returns the current span or transaction, or `nil` when none is bound.
    @objc open var span: Span? {
        get { synchronized(spanLock) { spanStorage } }
        set { replaceSpan(newValue) }
    }

    /// The id of the current session replay.
    @objc open var replayId: String?

    /// The dictionary of currently set tags.
    @objc open var tags: [String: String] {
        synchronized(tagDictionary) { stringDictionary(tagDictionary) }
    }

    /// The dictionary of currently set attributes.
    @objc open var attributes: [String: Any] {
        synchronized(attributesDictionary) { anyDictionary(attributesDictionary) }
    }

    /// Propagation context for events captured without a span.
    @_spi(Private) @objc public var propagationContext: SentryPropagationContext {
        get { synchronized(propagationContextLock) { propagationContextStorage } }
        set { replacePropagationContext(newValue) }
    }

    /// Trace id propagated when no span is bound.
    @_spi(Private) @objc public var propagationContextTraceId: SentryId {
        propagationContext.traceId
    }

    /// Trace header propagated when no span is bound.
    @_spi(Private) @objc public var propagationContextTraceHeader: TraceHeader {
        propagationContext.traceHeader
    }

    /// Screen name most recently reported to scope observers.
    @_spi(Private) @objc public var currentScreen: String? {
        get { currentScreenStorage }
        set { replaceCurrentScreen(newValue) }
    }

    /// Creates a scope that keeps at most `maxBreadcrumbs` breadcrumbs.
    @objc(initWithMaxBreadcrumbs:)
    public init(maxBreadcrumbs: Int) {
        let resolvedMax = UInt(max(0, maxBreadcrumbs))
        self.maxBreadcrumbs = resolvedMax
        breadcrumbArray = NSMutableArray(capacity: Int(resolvedMax))
        tagDictionary = NSMutableDictionary()
        extraDictionary = NSMutableDictionary()
        contextDictionary = NSMutableDictionary()
        fingerprintArray = NSMutableArray()
        attachmentArray = NSMutableArray()
        crashReportAttachmentArray = NSMutableArray()
        attributesDictionary = NSMutableDictionary()
        featureFlagBuffer = SentryFeatureFlagBufferWrapper.scopeBuffer()
        propagationContextStorage = SentryPropagationContext()
        super.init()
    }

    /// Creates a scope that keeps at most `maxBreadcrumbs` breadcrumbs and `maxFeatureFlags` evaluations.
    /// Internal so the public designated initializer stays source and binary stable.
    @_spi(Private)
    @objc(initWithMaxBreadcrumbs:maxFeatureFlags:)
    public convenience init(maxBreadcrumbs: Int, maxFeatureFlags: Int) {
        self.init(maxBreadcrumbs: maxBreadcrumbs)
        featureFlagBuffer = SentryFeatureFlagBufferWrapper.scopeBuffer(maxSize: max(0, maxFeatureFlags))
    }

    /// Creates a scope with the default breadcrumb limit.
    public required override convenience init() {
        self.init(maxBreadcrumbs: Int(defaultScopeMaxBreadcrumbs))
    }

    /// Creates a scope by copying another scope.
    @objc(initWithScope:)
    public convenience init(scope: Scope) {
        self.init(maxBreadcrumbs: Int(scope.maxBreadcrumbs))
        extraDictionary.addEntries(from: scope.extras())
        tagDictionary.addEntries(from: scope.tags)
        // Copy the context and the feature-flag buffer together so they stay consistent.
        synchronized(scope.contextDictionary) {
            contextDictionary.addEntries(from: scope.contextDictionary.copy() as? [AnyHashable: Any] ?? [:])
            featureFlagBuffer = scope.featureFlagBuffer.copyBuffer()
        }
        let crumbs = scope.breadcrumbs()
        breadcrumbArray = NSMutableArray(capacity: Int(scope.maxBreadcrumbs))
        currentBreadcrumbIndex = crumbs.count
        breadcrumbArray.addObjects(from: crumbs)
        fingerprintArray.addObjects(from: scope.fingerprints())
        attachmentArray.addObjects(from: scope.attachments)
        crashReportAttachmentArray.addObjects(from: scope.crashReportAttachments)
        attributesDictionary.addEntries(from: scope.attributes)

        propagationContext = scope.propagationContext
        maxBreadcrumbs = scope.maxBreadcrumbs
        // Read the source under its own lock, then write this scope's storage. Taking both
        // instance locks at once can deadlock when two scopes are copied from each other.
        var copiedUser: User?
        var copiedUserWasSet = false
        synchronized(scope) {
            copiedUser = scope.userObjectStorage?.copy() as? User
            copiedUserWasSet = scope.userWasSet
        }
        userObjectStorage = copiedUser
        userWasSet = copiedUserWasSet
        distStringStorage = scope.distString
        environmentStringStorage = scope.environmentString
        levelEnumStorage = scope.levelEnum
        span = scope.span
        replayId = scope.replayId
    }
}

private let kSentryScopeSpanStatusSerializationKey = "status"
private let defaultScopeMaxBreadcrumbs: UInt = 100

#if !SDK_V10
extension Scope: SentrySerializable {}
#endif

extension Scope {
    private func replaceSpan(_ span: Span?) {
        synchronized(spanLock) {
            spanStorage = span
            let observers = observerSnapshot()
            guard !observers.isEmpty else { return }
            let traceContext = buildTraceContext(span)
            for observer in observers {
                (observer as? SentryScopeObserver)?.setTraceContext(traceContext)
            }
        }
    }

    private func replacePropagationContext(_ propagationContext: SentryPropagationContext) {
        synchronized(propagationContextLock) {
            propagationContextStorage = propagationContext
            let observers = observerSnapshot()
            guard !observers.isEmpty else { return }
            let traceContext = propagationContext.traceContextForEvent()
            for observer in observers {
                (observer as? SentryScopeObserver)?.setTraceContext(traceContext)
            }
        }
    }

    private func replaceCurrentScreen(_ currentScreen: String?) {
        currentScreenStorage = currentScreen
        for observer in observerSnapshot() {
            observer.setCurrentScreen?(currentScreen)
        }
    }

    func applySpan(_ span: Span?, to event: Event) {
        var context = event.context ?? [:]
        let previousTraceId = context["trace"]?["trace_id"] as? String
        #if SDK_V10
        if event.type == SentryEnvelopeItemTypes.transaction, let transaction = event as? Transaction {
            // Transaction capture is asynchronous, so the scope may no longer hold its tracer.
            context["trace"] = transaction.trace.serialize()
        } else {
            context["trace"] = buildTraceContext(span)
        }
        #else
        context["trace"] = buildTraceContext(span)
        #endif
        event.context = context

        guard event.type != SentryEnvelopeItemTypes.transaction else { return }

        let updatedTraceId = context["trace"]?["trace_id"] as? String
        if let tracer = SentryTracer.getTracer(span) {
            event.transaction = tracer.transactionContext.name
        } else if span != nil, previousTraceId != nil, previousTraceId != updatedTraceId {
            event.transaction = nil
        }
    }

    func buildTraceContext(_ span: Span?) -> [String: Any] {
        #if SDK_V10
        // Public spans no longer require the SDK's internal serialization contract.
        if let serializable = span as? SentryInternalSerializable {
            return normalizedTraceContext(serializable.serialize())
        }
        return propagationContext.traceContextForEvent()
        #else
        if let span {
            return normalizedTraceContext(span.serialize())
        }
        return propagationContext.traceContextForEvent()
        #endif
    }

    private func normalizedTraceContext(_ dict: [String: Any]) -> [String: Any] {
        if dict[kSentryScopeSpanStatusSerializationKey] != nil {
            return dict
        }
        // Unfinished spans on the scope usually have no status. Default the trace context to OK
        // so it is not reported as undefined. Finishing a span still sets its own status.
        var mutable = dict
        mutable[kSentryScopeSpanStatusSerializationKey] = SentrySpanStatus.ok.name
        return mutable
    }

    /// Must be called while synchronized on `contextDictionary`.
    func updateFeatureFlagsContextLocked() {
        let featureFlags = featureFlagBuffer.serializeForContext()
        if let featureFlags, !featureFlags.isEmpty {
            contextDictionary["flags"] = featureFlags
        } else {
            contextDictionary.removeObject(forKey: "flags")
        }
        let contextCopy = contextDictionaryCopy()
        notifyObservers { $0.setContext(contextCopy) }
    }

    private func observerSnapshot() -> [AnyObject] {
        synchronized(observersLock) { observers }
    }

    func notifyObservers(_ body: (SentryScopeObserver) -> Void) {
        for observer in observerSnapshot() {
            guard let observer = observer as? SentryScopeObserver else { continue }
            body(observer)
        }
    }

    /// Recursively overlays `source` onto `destination`. Nested dictionaries merge; other values replace.
    func mergeEntries(from source: NSDictionary, into destination: NSMutableDictionary) {
        source.enumerateKeysAndObjects { key, value, _ in
            if let sourceDictionary = value as? NSDictionary,
               let existing = destination[key] as? NSDictionary {
                let merged = NSMutableDictionary(dictionary: existing)
                mergeEntries(from: sourceDictionary, into: merged)
                destination[key] = merged
                return
            }
            destination[key] = value
        }
    }

    func contextDictionaryCopy() -> [String: [String: Any]] {
        if let context = contextDictionary.copy() as? [String: [String: Any]] {
            return context
        }
        // One non-dictionary value must not discard the dictionaries beside it.
        return bridgedContext(contextDictionary)
    }

    /// Keeps every top-level dictionary. A value that is not a dictionary cannot be stored on
    /// `Event.context`, but it must not cause the merged dictionaries to be thrown away.
    func bridgedContext(_ dictionary: NSDictionary) -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        dictionary.enumerateKeysAndObjects { key, value, _ in
            guard let key = key as? String, let nested = value as? NSDictionary else { return }
            var inner: [String: Any] = [:]
            nested.enumerateKeysAndObjects { innerKey, innerValue, _ in
                guard let innerKey = innerKey as? String else { return }
                inner[innerKey] = innerValue
            }
            result[key] = inner
        }
        return result
    }

    func stringDictionary(_ dictionary: NSMutableDictionary) -> [String: String] {
        dictionary.copy() as? [String: String] ?? [:]
    }

    func anyDictionary(_ dictionary: NSMutableDictionary) -> [String: Any] {
        dictionary.copy() as? [String: Any] ?? [:]
    }

    func stringArray(_ array: NSMutableArray) -> [String] {
        array.copy() as? [String] ?? []
    }

    func objects<T>(of type: T.Type, in array: NSMutableArray) -> [T] {
        array.compactMap { $0 as? T }
    }
}
