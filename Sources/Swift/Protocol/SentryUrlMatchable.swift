import Foundation

/// A protocol that represents values that can be used for URL pattern matching.
///
/// Currently used by the network details API for session replay URL filtering.
/// May be reused by other SDK features requiring URL pattern matching in the future.
///
/// This protocol provides type safety for URL pattern arrays, preventing runtime errors
/// by enforcing valid types at compile time.
///
/// ```swift
/// options.networkDetailAllowUrls = [
///     "api.example.com",                                              // String ✅
///     try! NSRegularExpression(pattern: ".*\\.sentry\\.io.*")        // NSRegularExpression ✅
/// ]
/// options.networkDetailAllowUrls = [42]  // ❌ compile error — Int doesn't conform
/// ```
///
/// Conforming types: String (substring matching), NSRegularExpression (regex matching).
public protocol SentryUrlMatchable {
    /// Converts the conforming value to a `SentryUrlMatcher` enum representation.
    /// Internal SDK use only.
    var asSentryUrlMatcher: SentryUrlMatcher { get }
}

extension String: SentryUrlMatchable {
    /// Converts the string to a `SentryUrlMatcher.string` value for substring matching.
    public var asSentryUrlMatcher: SentryUrlMatcher {
        return .string(self)
    }
}

extension NSRegularExpression: SentryUrlMatchable {
    /// Converts the NSRegularExpression to a `SentryUrlMatcher.regex` value for full regex matching.
    public var asSentryUrlMatcher: SentryUrlMatcher {
        return .regex(self)
    }
}
