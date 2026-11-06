// swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity

internal import _SentryPrivate
import Foundation

/// The scope holds useful information that should be sent along with the event.
/// For instance tags or breadcrumbs are stored on the scope.
///
/// See https://docs.sentry.io/platforms/apple/enriching-events/scopes/#whats-a-scope-whats-a-hub
@objc(SentryScope)
open class Scope: NSObject {
    private let spanLock = NSObject()
    private let observersLock = NSObject()
    private let propagationContextLock = NSObject()
    /// Guards dist, environment, and level. These were atomic properties, so readers and writers
    /// share one lock. `userObject` stays on `synchronized(self)` with `setUser`.
    private let metadataLock = NSObject()

    private var spanStorage: Span?
    private var propagationContextStorage: SentryPropagationContext
    private var currentScreenStorage: String?
    private var observers: [AnyObject] = []

    /// Maximum number of breadcrumbs retained by this scope.
    /// Internal storage. The test category redeclares it; production code uses the initializer.
    @objc var maxBreadcrumbs: UInt
    private var currentBreadcrumbIndex = 0

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
    private var userWasSet = false
    private var userPersistenceCallback: ((User?) -> Void)?

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

    private var crashReportAttachmentArray: NSMutableArray
    private var attributesDictionary: NSMutableDictionary

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
        synchronized(self) {
            userObject = user
            userWasSet = true
            userPersistenceCallback?(user?.copy() as? User)
            notifyObservers { $0.setUser(user) }
        }
    }

    /// Installs the callback that records explicit user changes.
    ///
    /// When a user was already set, the callback runs immediately with a copy of that user.
    /// Passing `nil` detaches persistence. Copies of a scope do not inherit the callback.
    @_spi(Private)
    @objc(configureUserPersistence:)
    public func configureUserPersistence(_ callback: ((User?) -> Void)?) {
        synchronized(self) {
            userPersistenceCallback = callback
            if let callback, userWasSet {
                callback(userObject?.copy() as? User)
            }
        }
    }

    /// Restores a persisted user only while persistence is active and no explicit user decision has been made.
    @_spi(Private)
    @objc(restorePersistedUser:)
    public func restorePersistedUser(_ user: User) {
        synchronized(self) {
            guard userPersistenceCallback != nil, !userWasSet else { return }
            setUser(user)
        }
    }

    /// Sets a global tag. Tags are searchable key/value string pairs attached to every event.
    /// Passing `nil` removes the tag, matching `NSMutableDictionary` subscript assignment.
    @objc(setTagValue:forKey:)
    open func setTag(value: String?, key: String) {
        synchronized(tagDictionary) {
            if let value {
                tagDictionary[key] = value
            } else {
                tagDictionary.removeObject(forKey: key)
            }
            let tagsCopy = stringDictionary(tagDictionary)
            notifyObservers { $0.setTags(tagsCopy) }
        }
    }

    /// Removes the tag for the specified key.
    @objc(removeTagForKey:)
    open func removeTag(key: String) {
        synchronized(tagDictionary) {
            tagDictionary.removeObject(forKey: key)
            let tagsCopy = stringDictionary(tagDictionary)
            notifyObservers { $0.setTags(tagsCopy) }
        }
    }

    /// Sets global tags. Tags are searchable key/value string pairs attached to every event.
    @objc(setTags:)
    open func setTags(_ tags: [String: String]?) {
        guard let tags else { return }
        let tagsCopy = tags as NSDictionary
        synchronized(tagDictionary) {
            tagDictionary.addEntries(from: tagsCopy as? [AnyHashable: Any] ?? [:])
            let updated = stringDictionary(tagDictionary)
            notifyObservers { $0.setTags(updated) }
        }
    }

    /// Sets global extras sent with every event.
    @objc(setExtras:)
    open func setExtras(_ extras: [String: Any]?) {
        guard let extras else { return }
        synchronized(extraDictionary) {
            extraDictionary.addEntries(from: extras)
            let extrasCopy = anyDictionary(extraDictionary)
            notifyObservers { $0.setExtras(extrasCopy) }
        }
    }

    /// Sets one global extra sent with every event.
    @objc(setExtraValue:forKey:)
    open func setExtra(value: Any?, key: String) {
        synchronized(extraDictionary) {
            extraDictionary.setValue(value, forKey: key)
            let extrasCopy = anyDictionary(extraDictionary)
            notifyObservers { $0.setExtras(extrasCopy) }
        }
    }

    /// Removes the extra for the specified key.
    @objc(removeExtraForKey:)
    open func removeExtra(key: String) {
        synchronized(extraDictionary) {
            extraDictionary.removeObject(forKey: key)
            let extrasCopy = anyDictionary(extraDictionary)
            notifyObservers { $0.setExtras(extrasCopy) }
        }
    }

    /// Sets the distribution in the scope.
    @objc(setDist:)
    open func setDist(_ dist: String?) {
        distString = dist
        notifyObservers { $0.setDist(dist) }
    }

    /// Sets the environment in the scope.
    @objc(setEnvironment:)
    open func setEnvironment(_ environment: String?) {
        environmentString = environment
        notifyObservers { $0.setEnvironment(environment) }
    }

    /// Sets the fingerprint in the scope.
    @objc(setFingerprint:)
    open func setFingerprint(_ fingerprint: [String]?) {
        synchronized(fingerprintArray) {
            fingerprintArray.removeAllObjects()
            if let fingerprint {
                fingerprintArray.addObjects(from: fingerprint)
            }
            let fingerprintCopy = stringArray(fingerprintArray)
            notifyObservers { $0.setFingerprint(fingerprintCopy) }
        }
    }

    /// Sets the level in the scope.
    @objc(setLevel:)
    open func setLevel(_ level: SentryLevel) {
        levelEnum = level
        notifyObservers { $0.setLevel(level) }
    }

    /// Adds a breadcrumb to the scope.
    @objc(addBreadcrumb:)
    open func addBreadcrumb(_ crumb: Breadcrumb) {
        guard maxBreadcrumbs >= 1 else { return }
        SentrySDKLog.debug("Add breadcrumb: \(crumb.category) - \(crumb.message ?? "")")
        synchronized(breadcrumbArray) {
            // Ring buffer so adding a breadcrumb stays O(1). The scope owns a snapshot so a caller
            // mutating the breadcrumb afterwards cannot race with a reader of the stored object.
            let snapshot = crumb.snapshotCopy()
            breadcrumbArray[currentBreadcrumbIndex] = snapshot
            currentBreadcrumbIndex = (currentBreadcrumbIndex + 1) % Int(maxBreadcrumbs)
            let serializedBreadcrumb = snapshot.serialize()
            notifyObservers { $0.addSerializedBreadcrumb(serializedBreadcrumb) }
        }
    }

    /// Clears all breadcrumbs in the scope.
    @objc
    open func clearBreadcrumbs() {
        synchronized(breadcrumbArray) {
            currentBreadcrumbIndex = 0
            breadcrumbArray.removeAllObjects()
            notifyObservers { $0.clearBreadcrumbs() }
        }
    }

    /// Sets context values which overwrite `SentryEvent.context` when an event is enriched.
    /// The `flags` context key is reserved for feature flag evaluations.
    @objc(setContextValue:forKey:)
    open func setContext(value: [String: Any], key: String) {
        synchronized(contextDictionary) {
            contextDictionary.setValue(value, forKey: key)
            let contextCopy = contextDictionaryCopy()
            notifyObservers { $0.setContext(contextCopy) }
        }
    }

    /// Removes the context for the specified key.
    @objc(removeContextForKey:)
    open func removeContext(key: String) {
        synchronized(contextDictionary) {
            contextDictionary.removeObject(forKey: key)
            let contextCopy = contextDictionaryCopy()
            notifyObservers { $0.setContext(contextCopy) }
        }
    }

    /// Adds an attachment to every event sent to Sentry.
    ///
    /// The SDK doesn't add scope attachments to fatal events, such as crashes or watchdog
    /// terminations, because those are captured on the next app launch and the scope's attachments
    /// belong to that later run. Use `beforeSend` with a hint to attach files to fatal events.
    @objc(addAttachment:)
    open func addAttachment(_ attachment: Attachment) {
        synchronized(attachmentArray) {
            attachmentArray.add(attachment)
        }
    }

    /// Sets a global attribute. Attributes are searchable key/value pairs attached to every log.
    ///
    /// The SDK only applies attributes to logs. It doesn't apply them to events, transactions,
    /// spans, profiles, or session replay.
    /// Supported values are strings, integers, booleans, doubles, and arrays of those types.
    /// `key` cannot be an empty string.
    @objc(setAttributeValue:forKey:)
    open func setAttribute(value: Any, key: String) {
        guard !key.isEmpty else {
            SentrySDKLog.error("Attribute's key cannot be nil nor empty")
            return
        }
        synchronized(attributesDictionary) {
            attributesDictionary[key] = value
            let attributesCopy = anyDictionary(attributesDictionary)
            notifyObservers { $0.setAttributes(attributesCopy) }
        }
    }

    /// Removes the attribute for the specified key.
    ///
    /// The SDK only applies attributes to logs.
    @objc(removeAttributeForKey:)
    open func removeAttribute(key: String) {
        synchronized(attributesDictionary) {
            attributesDictionary.removeObject(forKey: key)
            let attributesCopy = anyDictionary(attributesDictionary)
            notifyObservers { $0.setAttributes(attributesCopy) }
        }
    }

    /// Clears all attachments in the scope.
    @objc
    open func clearAttachments() {
        synchronized(attachmentArray) {
            attachmentArray.removeAllObjects()
        }
    }

    /// Clears the current scope.
    ///
    /// Collections are emptied in place because each collection is also the lock that guards it.
    @objc
    open func clear() {
        clearBreadcrumbs()
        synchronized(tagDictionary) { tagDictionary.removeAllObjects() }
        synchronized(extraDictionary) { extraDictionary.removeAllObjects() }
        synchronized(contextDictionary) {
            contextDictionary.removeAllObjects()
            featureFlagBuffer.removeAll()
        }
        synchronized(fingerprintArray) { fingerprintArray.removeAllObjects() }
        clearAttachments()
        synchronized(spanLock) { spanStorage = nil }
        synchronized(attributesDictionary) { attributesDictionary.removeAllObjects() }

        synchronized(self) {
            userObject = nil
            userWasSet = true
            userPersistenceCallback?(nil)
        }
        distString = nil
        environmentString = nil
        levelEnum = .none

        notifyObservers { $0.clear() }
    }

    /// Attachments currently stored on the scope.
    @_spi(Private) @objc public var attachments: [Attachment] {
        synchronized(attachmentArray) { objects(of: Attachment.self, in: attachmentArray) }
    }

    /// Attachments captured for a fatal event, such as a screenshot or the view hierarchy.
    @_spi(Private) @objc public var crashReportAttachments: [Attachment] {
        synchronized(crashReportAttachmentArray) { objects(of: Attachment.self, in: crashReportAttachmentArray) }
    }

    /// Adds an attachment captured at crash time so it is sent with that fatal event.
    @_spi(Private)
    @objc(addCrashReportAttachmentInPath:)
    public func addCrashReportAttachment(inPath filePath: String) {
        let attachment: Attachment
        if (filePath as NSString).lastPathComponent == "view-hierarchy.json" {
            attachment = Attachment(
                path: filePath,
                filename: "view-hierarchy.json",
                contentType: "application/json",
                attachmentType: .viewHierarchy
            )
        } else {
            attachment = Attachment(path: filePath)
        }
        synchronized(crashReportAttachmentArray) {
            crashReportAttachmentArray.add(attachment)
        }
    }

    /// Breadcrumbs in chronological order.
    @_spi(Private) @objc public func breadcrumbs() -> [Breadcrumb] {
        synchronized(breadcrumbArray) {
            guard maxBreadcrumbs > 0 else { return [] }
            var crumbs: [Breadcrumb] = []
            for offset in 0 ..< Int(maxBreadcrumbs) {
                let index = (currentBreadcrumbIndex + offset) % Int(maxBreadcrumbs)
                guard index < breadcrumbArray.count, let crumb = breadcrumbArray[index] as? Breadcrumb else {
                    continue
                }
                crumbs.append(crumb)
            }
            return crumbs
        }
    }

    /// Extras currently stored on the scope.
    @_spi(Private) @objc public func extras() -> [String: Any] {
        synchronized(extraDictionary) { anyDictionary(extraDictionary) }
    }

    /// Context currently stored on the scope.
    @_spi(Private) @objc public func context() -> [String: [String: Any]] {
        synchronized(contextDictionary) { contextDictionaryCopy() }
    }

    /// Fingerprints currently stored on the scope.
    @_spi(Private) @objc public func fingerprints() -> [String] {
        synchronized(fingerprintArray) { stringArray(fingerprintArray) }
    }

    /// Returns the context dictionary for one key.
    @_spi(Private)
    @objc(getContextForKey:)
    public func getContextForKey(_ key: String) -> [String: Any]? {
        synchronized(contextDictionary) {
            contextDictionary[key] as? [String: Any]
        }
    }

    /// Applies the scope to a session.
    @_spi(Private)
    @objc(applyToSession:)
    public func applyTo(session: SentrySession) {
        // Environment set on options is not yet copied onto the scope, so it may be missing here.
        if let environment = environmentString {
            session.environment = environment
        }
    }

    /// Applies the scope to an event. Returns `nil` when `event` is `nil`.
    ///
    /// Crash events are left unchanged: they belong to the previous run, whose scope is not this one.
    @_spi(Private)
    @objc(applyToEvent:maxBreadcrumb:)
    @discardableResult
    public func applyTo(event: Event?, maxBreadcrumbs: UInt) -> Event? {
        guard let event else { return nil }
        if event.isFatalEvent {
            SentrySDKLog.warning(
                "Won't apply scope to a crash event. This is not allowed as crash "
                    + "events are from a previous run of the app and the current scope might "
                    + "have different data than the scope that was active during the crash."
            )
            return event
        }

        let scopeTags = tags
        if event.tags == nil {
            event.tags = scopeTags
        } else {
            var merged = scopeTags
            if let eventTags = event.tags {
                merged.merge(eventTags) { _, eventValue in eventValue }
            }
            event.tags = merged
        }

        let scopeExtras = extras()
        if event.extra == nil {
            event.extra = scopeExtras
        } else {
            var merged = scopeExtras
            if let eventExtra = event.extra {
                merged.merge(eventExtra) { _, eventValue in eventValue }
            }
            event.extra = merged
        }

        let scopeFingerprints = fingerprints()
        if !scopeFingerprints.isEmpty && event.fingerprint == nil {
            event.fingerprint = scopeFingerprints
        }

        if event.breadcrumbs == nil {
            let scopeBreadcrumbs = breadcrumbs()
            let length = min(max(0, Int(maxBreadcrumbs)), scopeBreadcrumbs.count)
            event.breadcrumbs = Array(scopeBreadcrumbs.prefix(length))
        }

        if let user = userObject?.copy() as? User {
            event.user = user
        }

        if let dist = distString, event.dist == nil {
            event.dist = dist
        }
        if let environment = environmentString, event.environment == nil {
            event.environment = environment
        }
        if levelEnum != .none {
            event.level = levelEnum
        }

        var newContext = context()
        let isRegularEvent = event.type == nil || event.type == SentryEnvelopeItemTypes.event
        if !isRegularEvent {
            newContext.removeValue(forKey: "flags")
        }
        if let eventContext = event.context {
            let merged = NSMutableDictionary(dictionary: newContext)
            mergeEntries(from: eventContext as NSDictionary, into: merged)
            event.context = merged as? [String: [String: Any]] ?? newContext
        } else {
            event.context = newContext
        }

        // The span getter acquires spanLock, so this read needs no outer lock.
        applySpan(span, to: event)
        return event
    }

    /// Overlays this scope onto an event that already has data from another scope.
    @_spi(Private)
    @objc(overlayOnEvent:maxBreadcrumb:)
    public func overlay(on event: Event, maxBreadcrumb: UInt) {
        let overlayTags = tags
        if !overlayTags.isEmpty {
            var merged = event.tags ?? [:]
            merged.merge(overlayTags) { _, overlayValue in overlayValue }
            event.tags = merged
        }

        let overlayExtras = extras()
        if !overlayExtras.isEmpty {
            var merged = event.extra ?? [:]
            merged.merge(overlayExtras) { _, overlayValue in overlayValue }
            event.extra = merged
        }

        if let overlayUser = userObject?.copy() as? User {
            event.user = overlayUser
        }

        let overlayFingerprint = fingerprints()
        if !overlayFingerprint.isEmpty {
            event.fingerprint = overlayFingerprint
        }

        let overlayBreadcrumbs = breadcrumbs()
        if !overlayBreadcrumbs.isEmpty {
            var merged = event.breadcrumbs ?? []
            for crumb in overlayBreadcrumbs where !merged.contains(where: { $0 === crumb }) {
                merged.append(crumb)
            }
            if merged.count > Int(maxBreadcrumb) {
                event.breadcrumbs = Array(merged.suffix(Int(maxBreadcrumb)))
            } else {
                event.breadcrumbs = merged
            }
        }

        if let overlayDist = distString {
            event.dist = overlayDist
        }
        if let overlayEnvironment = environmentString {
            event.environment = overlayEnvironment
        }
        if levelEnum != .none {
            event.level = levelEnum
        }

        let overlayContext = context()
        if !overlayContext.isEmpty {
            var merged = event.context ?? [:]
            let mergedDictionary = NSMutableDictionary(dictionary: merged)
            mergeEntries(from: overlayContext as NSDictionary, into: mergedDictionary)
            merged = mergedDictionary as? [String: [String: Any]] ?? merged
            let isRegularEvent = event.type == nil || event.type == SentryEnvelopeItemTypes.event
            if !isRegularEvent {
                merged.removeValue(forKey: "flags")
            }
            event.context = merged
        }

        if let span, !event.isFatalEvent, event.type != SentryEnvelopeItemTypes.transaction {
            applySpan(span, to: event)
        }
    }

    /// Runs `block` while holding the breadcrumb lock, so `addBreadcrumb` waits.
    ///
    /// Used to replay existing crumbs and attach an observer without a concurrent crumb being
    /// dropped or inserted ahead of the replay. Callers may re-enter breadcrumb reads.
    @_spi(Private)
    @objc(performWithBreadcrumbsLocked:)
    public func performWithBreadcrumbsLocked(_ block: () -> Void) {
        synchronized(breadcrumbArray) {
            block()
        }
    }

    /// Adds a scope observer. The observer is notified of later scope changes.
    ///
    /// The parameter is `AnyObject` so Objective-C observers that implement the callbacks can be
    /// registered without a Swift conformance in a header the Swift compiler imports.
    @_spi(Private)
    @objc(addScopeObserver:)
    public func add(_ observer: AnyObject) {
        synchronized(observersLock) {
            observers.append(observer)
        }
    }

    /// Replaces the propagation context and notifies observers.
    @_spi(Private)
    @objc(setPropagationContextWithTraceId:spanId:)
    public func setPropagationContext(traceId: SentryId, spanId: SpanId) {
        propagationContext = SentryPropagationContext(traceId: traceId, spanId: spanId)
    }

    /// Adds one feature-flag evaluation to the scope and to the active span.
    @_spi(Private)
    @objc(addFeatureFlagWithName:result:)
    public func addFeatureFlagInternal(name: String, result: Bool) {
        // Capture once so a concurrent span change cannot retarget the flag. Don't nest scope locks.
        let activeSpan: SentrySpanInternal? = synchronized(spanLock) {
            spanStorage as? SentrySpanInternal
        }
        synchronized(contextDictionary) {
            featureFlagBuffer.add(name: name, result: result)
            updateFeatureFlagsContextLocked()
        }
        activeSpan?.addFeatureFlagInternal(name: name, result: result)
    }

    /// Removes feature flags from the scope.
    @_spi(Private)
    @objc(clearFeatureFlags)
    public func clearFeatureFlagsInternal() {
        synchronized(contextDictionary) {
            featureFlagBuffer.removeAll()
            updateFeatureFlagsContextLocked()
        }
    }

    /// Returns the span when it is an SDK span, or `nil` for a custom span.
    func getCastedInternalSpan() -> SentrySpanInternal? {
        guard let span else { return nil }
        guard let internalSpan = span as? SentrySpanInternal else {
            SentrySDKLog.debug("The span on the scope is not of type SentrySpan, returning nil.")
            return nil
        }
        return internalSpan
    }

    #if !SDK_V10
    /// Serializes the scope to JSON.
    @objc
    @discardableResult
    open func serialize() -> [String: Any] {
        serializedScope()
    }
    #else
    @objc
    @discardableResult
    func serialize() -> [String: Any] {
        serializedScope()
    }
    #endif

    private func serializedScope() -> [String: Any] {
        let serializedData = NSMutableDictionary()
        let scopeTags = tags
        if !scopeTags.isEmpty {
            serializedData.setValue(scopeTags, forKey: "tags")
        }
        let scopeExtras = extras()
        if !scopeExtras.isEmpty {
            serializedData.setValue(scopeExtras, forKey: "extra")
        }

        var spanForTrace: Span?
        if span != nil {
            spanForTrace = synchronized(spanLock) { span }
        }
        serializedData["traceContext"] = buildTraceContext(spanForTrace)

        let scopeContext = context()
        if !scopeContext.isEmpty {
            serializedData.setValue(scopeContext, forKey: "context")
        }

        serializedData.setValue(userObject?.serialize(), forKey: "user")
        serializedData.setValue(distString, forKey: "dist")
        serializedData.setValue(environmentString, forKey: "environment")
        serializedData.setValue(replayId, forKey: "replay_id")
        let scopeFingerprints = fingerprints()
        if !scopeFingerprints.isEmpty {
            serializedData.setValue(scopeFingerprints, forKey: "fingerprint")
        }
        if levelEnum != .none {
            serializedData.setValue(SentryLevelHelper.nameForLevel(levelEnum), forKey: "level")
        }
        let crumbs = breadcrumbs().map { $0.serialize() }
        if !crumbs.isEmpty {
            serializedData.setValue(crumbs, forKey: "breadcrumbs")
        }
        let scopeAttributes = attributes
        if !scopeAttributes.isEmpty {
            serializedData.setValue(scopeAttributes, forKey: "attributes")
        }
        return serializedData as? [String: Any] ?? [:]
    }

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

    private func applySpan(_ span: Span?, to event: Event) {
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

    private func buildTraceContext(_ span: Span?) -> [String: Any] {
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
    private func updateFeatureFlagsContextLocked() {
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

    private func notifyObservers(_ body: (SentryScopeObserver) -> Void) {
        for observer in observerSnapshot() {
            guard let observer = observer as? SentryScopeObserver else { continue }
            body(observer)
        }
    }

    /// Recursively overlays `source` onto `destination`. Nested dictionaries merge; other values replace.
    private func mergeEntries(from source: NSDictionary, into destination: NSMutableDictionary) {
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

    private func contextDictionaryCopy() -> [String: [String: Any]] {
        contextDictionary.copy() as? [String: [String: Any]] ?? [:]
    }

    private func stringDictionary(_ dictionary: NSMutableDictionary) -> [String: String] {
        dictionary.copy() as? [String: String] ?? [:]
    }

    private func anyDictionary(_ dictionary: NSMutableDictionary) -> [String: Any] {
        dictionary.copy() as? [String: Any] ?? [:]
    }

    private func stringArray(_ array: NSMutableArray) -> [String] {
        array.copy() as? [String] ?? []
    }

    private func objects<T>(of type: T.Type, in array: NSMutableArray) -> [T] {
        array.compactMap { $0 as? T }
    }
}

private let kSentryScopeSpanStatusSerializationKey = "status"
private let defaultScopeMaxBreadcrumbs: UInt = 100

#if !SDK_V10
extension Scope: SentrySerializable {}
#endif

extension SentryHubInternal {
    /// The hub scope. Empty when the hub returns a value that is not a scope.
    var scope: Scope {
        guard let scope = scopeObject as? Scope else {
            SentrySDKLog.error("Hub scope was not a Scope instance.")
            return Scope()
        }
        return scope
    }

    /// Modifies the hub scope.
    func configureScope(_ callback: @escaping (Scope) -> Void) {
        configureScopeObject { scope in
            guard let scope = scope as? Scope else { return }
            callback(scope)
        }
    }
}

extension SentrySDKInternal {
    /// Modifies the current hub scope.
    static func configureScope(_ callback: @escaping (Scope) -> Void) {
        configureScopeObject { scope in
            guard let scope = scope as? Scope else { return }
            callback(scope)
        }
    }

    /// Captures an event, mutating a copy of the current scope for this call only.
    @discardableResult
    static func capture(event: Event, block: @escaping (Scope) -> Void) -> SentryId {
        capture(event: event, scopeBlockObject: scopeBlock(block))
    }

    /// Captures an error, mutating a copy of the current scope for this call only.
    @discardableResult
    static func capture(error: Error, block: @escaping (Scope) -> Void) -> SentryId {
        capture(error: error as NSError, scopeBlockObject: scopeBlock(block))
    }

    /// Captures an exception, mutating a copy of the current scope for this call only.
    @discardableResult
    static func capture(exception: NSException, block: @escaping (Scope) -> Void) -> SentryId {
        capture(exception: exception, scopeBlockObject: scopeBlock(block))
    }

    /// Captures a message, mutating a copy of the current scope for this call only.
    @discardableResult
    static func capture(message: String, block: @escaping (Scope) -> Void) -> SentryId {
        capture(message: message, scopeBlockObject: scopeBlock(block))
    }

    private static func scopeBlock(_ block: @escaping (Scope) -> Void) -> (Any) -> Void {
        { scope in
            guard let scope = scope as? Scope else { return }
            block(scope)
        }
    }
}

extension Scope {
    /// Adds a feature flag evaluation to the scope and the active span.
    @nonobjc public func addFeatureFlag(name: String, result: Bool) {
        addFeatureFlagInternal(name: name, result: result)
    }

    /// Removes feature flag evaluations from the scope.
    @nonobjc public func clearFeatureFlags() {
        clearFeatureFlagsInternal()
    }
}
