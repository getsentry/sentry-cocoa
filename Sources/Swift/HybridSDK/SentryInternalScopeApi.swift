// swiftlint:disable missing_docs
import Foundation

/// Scope APIs for Sentry hybrid SDKs.
public struct SentryInternalScopeApi {

    typealias Dependencies = HubProvider & CurrentScopeStorageProvider

    private let hub: Hub
    private let currentScopeStorage: SentryCurrentScopeStorage

    init(dependencies: Dependencies) {
        self.hub = dependencies.hub
        self.currentScopeStorage = dependencies.currentScopeStorage
    }

    /// Returns the current scope contexts in Sentry event wire format.
    public func serializedContexts() -> [String: [String: Any]] {
        let serializedScope = hub.scope.serialize()
        var contexts = serializedScope["context"] as? [String: [String: Any]] ?? [:]
        contexts["trace"] = serializedScope["traceContext"] as? [String: Any]
        return contexts
    }

    /// Sets the given scope as the current scope for the duration of the callback.
    ///
    /// Any capture calls made within the callback will have `scope` layered on
    /// top of the hub's global scope. The hub's scope is applied first, then
    /// `scope` overrides any conflicting fields.
    public func withCurrentScope(_ scope: Scope, _ callback: () -> Void) {
        currentScopeStorage.withScope(scope, callback: callback)
    }

    /// Creates a new empty scope.
    public func createScope() -> Scope {
        Scope()
    }

    /// Creates a deep copy of the given scope.
    public func cloneScope(_ scope: Scope) -> Scope {
        Scope(scope: scope)
    }
}
// swiftlint:enable missing_docs
