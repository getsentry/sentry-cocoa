import Foundation

/// A type-safe representation of URL pattern values used by network detail filtering.
///
/// `SentryUrlMatcher` provides a strongly-typed enum for representing URL pattern types
/// including strings and regular expressions.
///
/// - Note: This type should not be used directly. Use `String` or `NSRegularExpression`
/// when configuring URL patterns.
public enum SentryUrlMatcher {
    /// String pattern for substring matching.
    case string(String)
    /// NSRegularExpression pattern for regex matching.
    case regex(NSRegularExpression)

    /// Converts the matcher back to its underlying `SentryUrlMatchable` representation.
    var matchable: SentryUrlMatchable {
        switch self {
        case .string(let string):
            return string
        case .regex(let regex):
            return regex
        }
    }

    /// Evaluates whether the given URL string matches this pattern.
    func matches(url: String) -> Bool {
        switch self {
        case .string(let pattern):
            return url.contains(pattern)
        case .regex(let regex):
            let range = NSRange(url.startIndex..., in: url)
            return regex.firstMatch(in: url, range: range) != nil
        }
    }

    /// Converts an array of Any values to an array of SentryUrlMatchable, filtering out invalid types.
    ///
    /// Validates and filters entries: trim whitespace from strings, discard empty strings,
    /// and preserve only valid types (String and NSRegularExpression).
    ///
    /// - Parameter value: Array from dictionary that may contain mixed types
    /// - Returns: Array of valid SentryUrlMatchable values, or nil if input is not an array
    static func convertFromAny(_ value: Any?) -> [SentryUrlMatchable]? {
        guard let array = value as? [Any] else { return nil }
        return array.compactMap { element in
            if let string = element as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            if let regex = element as? NSRegularExpression { return regex }
            return nil
        }
    }
}
