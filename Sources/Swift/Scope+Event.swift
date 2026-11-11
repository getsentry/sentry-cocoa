internal import _SentryPrivate
import Foundation

/// Keeps this file linked in static builds. Referenced from `SentrySDKInternal`.
@_spi(Private) @objc public final class PlaceholderScopeEventClass: NSObject {}

extension Scope {
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

        applyTags(to: event)
        applyExtras(to: event)
        applyFingerprint(to: event)
        applyBreadcrumbs(to: event, maxBreadcrumbs: maxBreadcrumbs)
        applyUser(to: event)
        applyDistEnvironmentAndLevel(to: event)
        applyContext(to: event)
        // The span getter acquires spanLock, so this read needs no outer lock.
        applySpan(span, to: event)
        return event
    }

    private func applyTags(to event: Event) {
        let scopeTags = tags
        guard let eventTags = event.tags else {
            event.tags = scopeTags
            return
        }
        var merged = scopeTags
        merged.merge(eventTags) { _, eventValue in eventValue }
        event.tags = merged
    }

    private func applyExtras(to event: Event) {
        let scopeExtras = extras()
        guard let eventExtra = event.extra else {
            event.extra = scopeExtras
            return
        }
        var merged = scopeExtras
        merged.merge(eventExtra) { _, eventValue in eventValue }
        event.extra = merged
    }

    private func applyFingerprint(to event: Event) {
        let scopeFingerprints = fingerprints()
        guard !scopeFingerprints.isEmpty, event.fingerprint == nil else {
            return
        }
        event.fingerprint = scopeFingerprints
    }

    private func applyBreadcrumbs(to event: Event, maxBreadcrumbs: UInt) {
        guard event.breadcrumbs == nil else {
            return
        }
        let scopeBreadcrumbs = breadcrumbs()
        // Clamp in UInt. Int(maxBreadcrumbs) traps when the limit is above Int.max.
        let limit = min(maxBreadcrumbs, UInt(scopeBreadcrumbs.count))
        event.breadcrumbs = Array(scopeBreadcrumbs.prefix(Int(limit)))
    }

    private func applyUser(to event: Event) {
        guard let user = userObject?.copy() as? User else {
            return
        }
        event.user = user
    }

    private func applyDistEnvironmentAndLevel(to event: Event) {
        if let dist = distString, event.dist == nil {
            event.dist = dist
        }
        if let environment = environmentString, event.environment == nil {
            event.environment = environment
        }
        let level = levelEnum
        guard level != .none else {
            return
        }
        event.level = level
    }

    private func applyContext(to event: Event) {
        var newContext = context()
        let isRegularEvent = event.type == nil || event.type == SentryEnvelopeItemTypes.event
        if !isRegularEvent {
            newContext.removeValue(forKey: "flags")
        }
        guard let eventContext = event.context else {
            event.context = newContext
            return
        }
        let merged = NSMutableDictionary(dictionary: newContext)
        mergeEntries(from: eventContext as NSDictionary, into: merged)
        event.context = merged as? [String: [String: Any]] ?? bridgedContext(merged)
    }

    /// Overlays this scope onto an event that already has data from another scope.
    @_spi(Private)
    @objc(overlayOnEvent:maxBreadcrumb:)
    public func overlay(on event: Event, maxBreadcrumb: UInt) {
        overlayTags(on: event)
        overlayExtras(on: event)
        overlayUser(on: event)
        overlayFingerprint(on: event)
        overlayBreadcrumbs(on: event, maxBreadcrumb: maxBreadcrumb)
        overlayDistEnvironmentAndLevel(on: event)
        overlayContext(on: event)
        overlaySpan(on: event)
    }

    private func overlayTags(on event: Event) {
        let overlayTags = tags
        guard !overlayTags.isEmpty else {
            return
        }
        var merged = event.tags ?? [:]
        merged.merge(overlayTags) { _, overlayValue in overlayValue }
        event.tags = merged
    }

    private func overlayExtras(on event: Event) {
        let overlayExtras = extras()
        guard !overlayExtras.isEmpty else {
            return
        }
        var merged = event.extra ?? [:]
        merged.merge(overlayExtras) { _, overlayValue in overlayValue }
        event.extra = merged
    }

    private func overlayUser(on event: Event) {
        guard let overlayUser = userObject?.copy() as? User else {
            return
        }
        event.user = overlayUser
    }

    private func overlayFingerprint(on event: Event) {
        let overlayFingerprint = fingerprints()
        guard !overlayFingerprint.isEmpty else {
            return
        }
        event.fingerprint = overlayFingerprint
    }

    private func overlayBreadcrumbs(on event: Event, maxBreadcrumb: UInt) {
        let overlayBreadcrumbs = breadcrumbs()
        guard !overlayBreadcrumbs.isEmpty else {
            return
        }
        var merged = event.breadcrumbs ?? []
        for crumb in overlayBreadcrumbs where !merged.contains(where: { $0 === crumb }) {
            merged.append(crumb)
        }
        // Clamp in UInt. Int(maxBreadcrumb) traps when the limit is above Int.max.
        let limit = min(maxBreadcrumb, UInt(merged.count))
        event.breadcrumbs = Array(merged.suffix(Int(limit)))
    }

    private func overlayDistEnvironmentAndLevel(on event: Event) {
        if let overlayDist = distString {
            event.dist = overlayDist
        }
        if let overlayEnvironment = environmentString {
            event.environment = overlayEnvironment
        }
        let level = levelEnum
        guard level != .none else {
            return
        }
        event.level = level
    }

    private func overlayContext(on event: Event) {
        let overlayContext = context()
        guard !overlayContext.isEmpty else {
            return
        }
        var merged = event.context ?? [:]
        let mergedDictionary = NSMutableDictionary(dictionary: merged)
        mergeEntries(from: overlayContext as NSDictionary, into: mergedDictionary)
        merged = mergedDictionary as? [String: [String: Any]] ?? bridgedContext(mergedDictionary)
        let isRegularEvent = event.type == nil || event.type == SentryEnvelopeItemTypes.event
        if !isRegularEvent {
            merged.removeValue(forKey: "flags")
        }
        event.context = merged
    }

    private func overlaySpan(on event: Event) {
        guard let span, !event.isFatalEvent, event.type != SentryEnvelopeItemTypes.transaction else {
            return
        }
        applySpan(span, to: event)
    }

    #if SDK_V10
    @objc
    @discardableResult
    func serialize() -> [String: Any] {
        serializedScope()
    }
    #endif

    func serializedScope() -> [String: Any] {
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
        let level = levelEnum
        if level != .none {
            serializedData.setValue(SentryLevelHelper.nameForLevel(level), forKey: "level")
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
}
