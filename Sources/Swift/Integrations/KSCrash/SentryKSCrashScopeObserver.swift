@_implementationOnly import _SentryPrivate
import Foundation

/// Observes `SentryScope` changes and serializes the current scope state to a JSON
/// string that KSCrash can embed in crash reports via `sentryKSCrash_setScopeJSON`.
///
/// Breadcrumbs are stored in a fixed-capacity ring buffer that automatically evicts
/// the oldest entry when full.
///
/// Thread-safety note: `SentryScope` copies mutable collections before passing them
/// to observers, so the values received here are already immutable snapshots and no
/// additional locking is required on the Swift side.
final class SentryKSCrashScopeObserver: NSObject, SentryScopeObserver {

    private let maxBreadcrumbs: Int
    /// Ring buffer: each slot holds an already-serialized breadcrumb dictionary.
    private var breadcrumbs: [[String: Any]?]
    /// Index of the *next write* slot (also the oldest slot when the buffer is full).
    private var breadcrumbIndex = 0

    private var user: User?
    private var dist: String?
    private var environment: String?
    private var tags: [String: String]?
    private var extras: [String: Any]?
    private var context: [String: [String: Any]]?
    private var traceContext: [String: Any]?
    private var fingerprint: [String]?
    private var level: SentryLevel = .none

    @objc init(maxBreadcrumbs: Int) {
        self.maxBreadcrumbs = max(1, maxBreadcrumbs)
        self.breadcrumbs = [[String: Any]?](repeating: nil, count: self.maxBreadcrumbs)
        super.init()
    }

    // MARK: - SentryScopeObserver

    func setUser(_ user: User?) {
        self.user = user
        flush()
    }

    func setTags(_ tags: [String: String]?) {
        self.tags = tags
        flush()
    }

    func setExtras(_ extras: [String: Any]?) {
        self.extras = extras
        flush()
    }

    func setContext(_ context: [String: [String: Any]]?) {
        self.context = context
        flush()
    }

    func setTraceContext(_ traceContext: [String: Any]?) {
        self.traceContext = traceContext
        flush()
    }

    func setDist(_ dist: String?) {
        self.dist = dist
        flush()
    }

    func setEnvironment(_ environment: String?) {
        self.environment = environment
        flush()
    }

    func setFingerprint(_ fingerprint: [String]?) {
        self.fingerprint = fingerprint
        flush()
    }

    func setLevel(_ level: SentryLevel) {
        self.level = level
        flush()
    }

    func setAttributes(_ attributes: [String: Any]?) {
        // Crash events don't support attributes — nothing to do.
    }

    func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {
        breadcrumbs[breadcrumbIndex] = serializedBreadcrumb
        breadcrumbIndex = (breadcrumbIndex + 1) % maxBreadcrumbs
        flush()
    }

    func clearBreadcrumbs() {
        breadcrumbs = [[String: Any]?](repeating: nil, count: maxBreadcrumbs)
        breadcrumbIndex = 0
        flush()
    }

    func clear() {
        user = nil
        dist = nil
        environment = nil
        tags = nil
        extras = nil
        context = nil
        traceContext = nil
        fingerprint = nil
        level = .none
        breadcrumbs = [[String: Any]?](repeating: nil, count: maxBreadcrumbs)
        breadcrumbIndex = 0
        flush()
    }

    // MARK: - Private

    private func flush() {
        var scope = buildScopeDictionary()

        let orderedCrumbs = orderedBreadcrumbs()
        if !orderedCrumbs.isEmpty {
            scope["breadcrumbs"] = orderedCrumbs
        }

        guard let data = try? JSONSerialization.data(withJSONObject: scope),
              let json = String(data: data, encoding: .utf8) else { return }

        sentryKSCrash_setScopeJSON(json)
    }

    // swiftlint:disable:next function_body_length
    private func buildScopeDictionary() -> [String: Any] {
        var scope: [String: Any] = [:]

        if let user = user {
            scope["user"] = user.serialize()
        }
        if let dist = dist {
            scope["dist"] = dist
        }
        if let environment = environment {
            scope["environment"] = environment
        }
        if let tags = tags, !tags.isEmpty {
            scope["tags"] = tags
        }
        if let extras = extras, !extras.isEmpty {
            scope["extra"] = extras
        }
        if let context = context, !context.isEmpty {
            scope["context"] = context
        }
        if let traceContext = traceContext {
            scope["trace_context"] = traceContext
        }
        if let fingerprint = fingerprint, !fingerprint.isEmpty {
            scope["fingerprint"] = fingerprint
        }
        if level != .none {
            scope["level"] = level.description
        }

        return scope
    }

    /// Returns breadcrumbs in insertion order (oldest first) by reading the ring
    /// buffer starting from the oldest slot.
    private func orderedBreadcrumbs() -> [[String: Any]] {
        (0..<maxBreadcrumbs).compactMap { i in
            breadcrumbs[(breadcrumbIndex + i) % maxBreadcrumbs]
        }
    }
}
