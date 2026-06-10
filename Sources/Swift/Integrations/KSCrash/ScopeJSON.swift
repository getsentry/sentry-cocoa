@_implementationOnly import _SentryPrivate
import Foundation

/// Stores pre-serialized JSON value strings for each scope field and assembles
/// the full scope JSON object lazily on `get()`.
///
/// All mutations are serialized through a single lock. `get()` is O(n fields)
/// string concatenation with no JSON serialization — suitable to call from a
/// crash handler.
final class ScopeJSON {

    private static let lock = NSLock()

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

    static func setUser(_ json: String?)         { lock.withLock { userJSON = json } }
    static func setDist(_ json: String?)         { lock.withLock { distJSON = json } }
    static func setEnvironment(_ json: String?)  { lock.withLock { environmentJSON = json } }
    static func setTags(_ json: String?)         { lock.withLock { tagsJSON = json } }
    static func setExtras(_ json: String?)       { lock.withLock { extrasJSON = json } }
    static func setContext(_ json: String?)      { lock.withLock { contextJSON = json } }
    static func setTraceContext(_ json: String?) { lock.withLock { traceContextJSON = json } }
    static func setFingerprint(_ json: String?)  { lock.withLock { fingerprintJSON = json } }
    static func setLevel(_ json: String?)        { lock.withLock { levelJSON = json } }

    // MARK: - Breadcrumbs

    static func configureBreadcrumbs(max: Int) {
        lock.withLock {
            maxBreadcrumbs = max
            breadcrumbs = [String?](repeating: nil, count: max)
            breadcrumbIndex = 0
        }
    }

    static func addBreadcrumb(_ json: String) {
        lock.withLock {
            guard maxBreadcrumbs > 0 else { return }
            breadcrumbs[breadcrumbIndex] = json
            breadcrumbIndex = (breadcrumbIndex + 1) % maxBreadcrumbs
        }
    }

    static func clearBreadcrumbs() {
        lock.withLock {
            breadcrumbs = [String?](repeating: nil, count: maxBreadcrumbs)
            breadcrumbIndex = 0
        }
    }

    // MARK: - Assembly

    /// Assembles all stored fragments into a JSON object string.
    /// Returns `nil` when no fields are set.
    static func get() -> String? {
        lock.withLock {
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

            let crumbs = assembledBreadcrumbs()
            if let crumbs { parts.append("\"breadcrumbs\":\(crumbs)") }

            return parts.isEmpty ? nil : "{\(parts.joined(separator: ","))}"
        }
    }

    // MARK: - Clear

    static func clear() {
        lock.withLock {
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

    /// Must be called with `lock` already held.
    private static func assembledBreadcrumbs() -> String? {
        let crumbs = (0..<maxBreadcrumbs).compactMap { i in
            breadcrumbs[(breadcrumbIndex + i) % maxBreadcrumbs]
        }
        return crumbs.isEmpty ? nil : "[\(crumbs.joined(separator: ","))]"
    }
}
