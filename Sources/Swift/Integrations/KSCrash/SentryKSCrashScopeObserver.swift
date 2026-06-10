@_implementationOnly import _SentryPrivate
import Foundation

/// Observes `SentryScope` changes and forwards pre-serialized JSON fragments to
/// `ScopeJSON`, which assembles them into the crash report's scope JSON on demand.
///
/// This class is stateless: each callback serializes only its own argument and
/// delegates storage and assembly to `ScopeJSON`. Thread safety is handled there.
final class SentryKSCrashScopeObserver: NSObject, SentryScopeObserver {

    @objc init(maxBreadcrumbs: Int) {
        super.init()
        ScopeJSON.configureBreadcrumbs(max: max(1, maxBreadcrumbs))
    }

    // MARK: - SentryScopeObserver

    func setUser(_ user: User?) {
        ScopeJSON.setUser(jsonValue(user?.serialize()))
    }

    func setTags(_ tags: [String: String]?) {
        ScopeJSON.setTags(jsonValue(tags))
    }

    func setExtras(_ extras: [String: Any]?) {
        ScopeJSON.setExtras(jsonValue(extras))
    }

    func setContext(_ context: [String: [String: Any]]?) {
        ScopeJSON.setContext(jsonValue(context))
    }

    func setTraceContext(_ traceContext: [String: Any]?) {
        ScopeJSON.setTraceContext(jsonValue(traceContext))
    }

    func setDist(_ dist: String?) {
        ScopeJSON.setDist(dist.flatMap { serialize($0) })
    }

    func setEnvironment(_ environment: String?) {
        ScopeJSON.setEnvironment(environment.flatMap { serialize($0) })
    }

    func setFingerprint(_ fingerprint: [String]?) {
        ScopeJSON.setFingerprint(jsonValue(fingerprint))
    }

    func setLevel(_ level: SentryLevel) {
        ScopeJSON.setLevel(level == .none ? nil : serialize(level.description))
    }

    func setAttributes(_ attributes: [String: Any]?) {
        // Crash events don't support attributes — nothing to do.
    }

    func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: serializedBreadcrumb),
              let json = String(data: data, encoding: .utf8) else { return }
        ScopeJSON.addBreadcrumb(json)
    }

    func clearBreadcrumbs() {
        ScopeJSON.clearBreadcrumbs()
    }

    func clear() {
        ScopeJSON.clear()
    }

    // MARK: - Private

    /// Serializes an object to a compact JSON value string, returning `nil` if the
    /// object is `nil`, empty, or un-serializable.
    private func jsonValue(_ object: Any?) -> String? {
        guard let object else { return nil }
        // Treat empty collections as nil so we don't write empty JSON objects.
        if let dict = object as? [String: Any], dict.isEmpty { return nil }
        if let arr = object as? [Any], arr.isEmpty { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    private func serialize(_ value: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    private func serialize(_ value: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }
}
