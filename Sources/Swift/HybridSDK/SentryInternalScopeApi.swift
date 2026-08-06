// swiftlint:disable missing_docs
import Foundation

/// Scope APIs for Sentry hybrid SDKs.
public struct SentryInternalScopeApi {

    typealias Dependencies = HubProvider

    private let hub: Hub

    init(dependencies: Dependencies) {
        self.hub = dependencies.hub
    }

    /// Returns the current scope contexts in Sentry event wire format.
    public func serializedContexts() -> [String: [String: Any]] {
        let serializedScope = hub.scope.serialize()
        var contexts = serializedScope["context"] as? [String: [String: Any]] ?? [:]
        contexts["trace"] = serializedScope["traceContext"] as? [String: Any]
        return contexts
    }
}
// swiftlint:enable missing_docs
