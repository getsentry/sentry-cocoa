@_implementationOnly import _SentryPrivate
import Foundation

/// Stores pre-serialized JSON value strings for each scope field.
///
/// Every mutation rebuilds a cached JSON object string under the lock so that
/// `get()` only needs to read one pre-built value — keeping the lock window in
/// the crash-time read path as short as possible.
final class ScopeJSON {

    private static let lock = NSLock()

    private static var cachedJSON: String?

    private static var userJSON: String?
    private static var distJSON: String?
    private static var environmentJSON: String?
    private static var tagsJSON: String?
    private static var extrasJSON: String?
    private static var contextJSON: String?
    private static var traceContextJSON: String?
    private static var fingerprintJSON: String?
    private static var levelJSON: String?

    private static var breadcrumbs: [String?] = []
    private static var breadcrumbIndex = 0
    private static var maxBreadcrumbs = 0

    // MARK: - Field setters

    static func setUser(_ json: String?)         { mutate { userJSON = json } }
    static func setDist(_ json: String?)         { mutate { distJSON = json } }
    static func setEnvironment(_ json: String?)  { mutate { environmentJSON = json } }
    static func setTags(_ json: String?)         { mutate { tagsJSON = json } }
    static func setExtras(_ json: String?)       { mutate { extrasJSON = json } }
    static func setContext(_ json: String?)      { mutate { contextJSON = json } }
    static func setTraceContext(_ json: String?) { mutate { traceContextJSON = json } }
    static func setFingerprint(_ json: String?)  { mutate { fingerprintJSON = json } }
    static func setLevel(_ json: String?)        { mutate { levelJSON = json } }

    // MARK: - Breadcrumbs

    static func configureBreadcrumbs(max: Int) {
        mutate {
            maxBreadcrumbs = max
            breadcrumbs = [String?](repeating: nil, count: max)
            breadcrumbIndex = 0
        }
    }

    static func addBreadcrumb(_ json: String) {
        mutate {
            guard maxBreadcrumbs > 0 else { return }
            breadcrumbs[breadcrumbIndex] = json
            breadcrumbIndex = (breadcrumbIndex + 1) % maxBreadcrumbs
        }
    }

    static func clearBreadcrumbs() {
        mutate {
            breadcrumbs = [String?](repeating: nil, count: maxBreadcrumbs)
            breadcrumbIndex = 0
        }
    }

    // MARK: - Read

    /// Returns the pre-assembled scope JSON string.
    /// Acquires the lock only to read a single stored value.
    static func get() -> String? {
        lock.withLock { cachedJSON }
    }

    // MARK: - Clear

    static func clear() {
        mutate {
            userJSON = nil
            distJSON = nil
            environmentJSON = nil
            tagsJSON = nil
            extrasJSON = nil
            contextJSON = nil
            traceContextJSON = nil
            fingerprintJSON = nil
            levelJSON = nil
            breadcrumbs = [String?](repeating: nil, count: maxBreadcrumbs)
            breadcrumbIndex = 0
        }
    }

    // MARK: - Private

    /// Acquires the lock, applies `mutation`, then rebuilds `cachedJSON`.
    private static func mutate(_ mutation: () -> Void) {
        lock.withLock {
            mutation()
            cachedJSON = assemble()
        }
    }

    /// Builds the scope JSON object string from current fragments.
    /// Must be called with `lock` already held.
    private static func assemble() -> String? {
        var parts: [String] = []
        if let j = userJSON         { parts.append("\"user\":\(j)") }
        if let j = distJSON         { parts.append("\"dist\":\(j)") }
        if let j = environmentJSON  { parts.append("\"environment\":\(j)") }
        if let j = tagsJSON         { parts.append("\"tags\":\(j)") }
        if let j = extrasJSON       { parts.append("\"extra\":\(j)") }
        if let j = contextJSON      { parts.append("\"context\":\(j)") }
        if let j = traceContextJSON { parts.append("\"trace_context\":\(j)") }
        if let j = fingerprintJSON  { parts.append("\"fingerprint\":\(j)") }
        if let j = levelJSON        { parts.append("\"level\":\(j)") }

        let crumbs = (0..<maxBreadcrumbs).compactMap { i in
            breadcrumbs[(breadcrumbIndex + i) % maxBreadcrumbs]
        }
        if !crumbs.isEmpty {
            parts.append("\"breadcrumbs\":[\(crumbs.joined(separator: ","))]")
        }

        return parts.isEmpty ? nil : "{\(parts.joined(separator: ","))}"
    }
}
