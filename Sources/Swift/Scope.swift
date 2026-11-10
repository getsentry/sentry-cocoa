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

    /// Sets the user sent with every event.
    @objc(setUser:)
    open func setUser(_ user: User?) {
        storeUser(user)
    }

    /// Sets a global tag. Tags are searchable key/value string pairs attached to every event.
    /// Passing `nil` removes the tag, matching `NSMutableDictionary` subscript assignment.
    @objc(setTagValue:forKey:)
    open func setTag(value: String?, key: String) {
        storeTag(value: value, key: key)
    }

    /// Removes the tag for the specified key.
    @objc(removeTagForKey:)
    open func removeTag(key: String) {
        deleteTag(key: key)
    }

    /// Sets global tags. Tags are searchable key/value string pairs attached to every event.
    @objc(setTags:)
    open func setTags(_ tags: [String: String]?) {
        storeTags(tags)
    }

    /// Sets global extras sent with every event.
    @objc(setExtras:)
    open func setExtras(_ extras: [String: Any]?) {
        storeExtras(extras)
    }

    /// Sets one global extra sent with every event.
    @objc(setExtraValue:forKey:)
    open func setExtra(value: Any?, key: String) {
        storeExtra(value: value, key: key)
    }

    /// Removes the extra for the specified key.
    @objc(removeExtraForKey:)
    open func removeExtra(key: String) {
        deleteExtra(key: key)
    }

    /// Sets the distribution in the scope.
    @objc(setDist:)
    open func setDist(_ dist: String?) {
        storeDist(dist)
    }

    /// Sets the environment in the scope.
    @objc(setEnvironment:)
    open func setEnvironment(_ environment: String?) {
        storeEnvironment(environment)
    }

    /// Sets the fingerprint in the scope.
    @objc(setFingerprint:)
    open func setFingerprint(_ fingerprint: [String]?) {
        storeFingerprint(fingerprint)
    }

    /// Sets the level in the scope.
    @objc(setLevel:)
    open func setLevel(_ level: SentryLevel) {
        storeLevel(level)
    }

    /// Adds a breadcrumb to the scope.
    @objc(addBreadcrumb:)
    open func addBreadcrumb(_ crumb: Breadcrumb) {
        storeBreadcrumb(crumb)
    }

    /// Clears all breadcrumbs in the scope.
    @objc
    open func clearBreadcrumbs() {
        deleteBreadcrumbs()
    }

    /// Sets context values which overwrite `SentryEvent.context` when an event is enriched.
    /// The `flags` context key is reserved for feature flag evaluations.
    @objc(setContextValue:forKey:)
    open func setContext(value: [String: Any], key: String) {
        storeContext(value: value, key: key)
    }

    /// Removes the context for the specified key.
    @objc(removeContextForKey:)
    open func removeContext(key: String) {
        deleteContext(key: key)
    }

    /// Adds an attachment to every event sent to Sentry.
    ///
    /// The SDK doesn't add scope attachments to fatal events, such as crashes or watchdog
    /// terminations, because those are captured on the next app launch and the scope's attachments
    /// belong to that later run. Use `beforeSend` with a hint to attach files to fatal events.
    @objc(addAttachment:)
    open func addAttachment(_ attachment: Attachment) {
        storeAttachment(attachment)
    }

    /// Sets a global attribute. Attributes are searchable key/value pairs attached to every log.
    ///
    /// The SDK only applies attributes to logs. It doesn't apply them to events, transactions,
    /// spans, profiles, or session replay.
    /// Supported values are strings, integers, booleans, doubles, and arrays of those types.
    /// `key` cannot be an empty string.
    @objc(setAttributeValue:forKey:)
    open func setAttribute(value: Any, key: String) {
        storeAttribute(value: value, key: key)
    }

    /// Removes the attribute for the specified key.
    ///
    /// The SDK only applies attributes to logs.
    @objc(removeAttributeForKey:)
    open func removeAttribute(key: String) {
        deleteAttribute(key: key)
    }

    /// Clears all attachments in the scope.
    @objc
    open func clearAttachments() {
        deleteAttachments()
    }

    /// Clears the current scope.
    ///
    /// Collections are emptied in place because each collection is also the lock that guards it.
    @objc
    open func clear() {
        resetScope()
    }

    #if !SDK_V10
    /// Serializes the scope to JSON.
    @objc
    @discardableResult
    open func serialize() -> [String: Any] {
        serializedScope()
    }
    #endif
}

private let defaultScopeMaxBreadcrumbs: UInt = 100

#if !SDK_V10
extension Scope: SentrySerializable {}
#endif

private extension Scope {
    func replaceSpan(_ span: Span?) {
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

    func replacePropagationContext(_ propagationContext: SentryPropagationContext) {
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

    func replaceCurrentScreen(_ currentScreen: String?) {
        currentScreenStorage = currentScreen
        for observer in observerSnapshot() {
            observer.setCurrentScreen?(currentScreen)
        }
    }
}
