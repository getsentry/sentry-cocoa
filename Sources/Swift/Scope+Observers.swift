internal import _SentryPrivate
import Foundation

/// Keeps this file linked in static builds. Referenced from `SentrySDKInternal`.
@_spi(Private) @objc public final class PlaceholderScopeObserversClass: NSObject {}

extension Scope {
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
}

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
