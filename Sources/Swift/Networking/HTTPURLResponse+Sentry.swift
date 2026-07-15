import Foundation

// The instance methods are `internal` (not `private`) so the pre-macOS-10.15 fallback can be
// unit-tested; `#available` makes it unreachable on the OS versions our tests run on.
extension HTTPURLResponse {

    /// Reads a header case-insensitively.
    /// Since HTTP/2 HTTP field names are case-insensitive including HTTP headers; see HTTP/2 (RFC 9113, 8.2.1) and HTTP/3 (RFC 9114, 4.2):
    /// - https://www.rfc-editor.org/rfc/rfc9113#section-8.2.1
    /// - https://www.rfc-editor.org/rfc/rfc9114#section-4.2
    func value(forHTTPHeaderFieldCaseInsensitive name: String) -> String? {
        if #available(macOS 10.15, *) {
            // `value(forHTTPHeaderField:)` retrieves the header case-insensitively.
            return value(forHTTPHeaderField: name)
        }
        return sentryCaseInsensitiveHeaderValue(forName: name)
    }

    /// Pre-macOS-10.15 fallback is an extra method so it can be unit tested. We plan on bumping to macOS 12
    /// in August 2026, so we don't use this implementation for all platforms.
    ///
    /// `allHeaderFields` subscripting is case-sensitive, so we scan all keys and compare them
    /// case-insensitively against `name`. This is O(n), which is acceptable for the small number of
    /// response headers.
    func sentryCaseInsensitiveHeaderValue(forName name: String) -> String? {
        let lowercasedName = name.lowercased()
        // The linter forbids `allHeaderFields` because its subscript is case-sensitive, and it points
        // callers to `value(forHTTPHeaderField:)`. That API is only available on macOS 10.15+, so this
        // pre-10.15 fallback has to iterate `allHeaderFields` instead. The case-sensitivity bug the
        // linter guards against doesn't apply here: we don't subscript, we compare every key against
        // `name` with both sides lowercased.
        // swiftlint:disable avoid_all_header_fields
        for (key, value) in allHeaderFields {
            if let key = key as? String, key.lowercased() == lowercasedName {
                return value as? String
            }
        }
        // swiftlint:enable avoid_all_header_fields
        return nil
    }
}

/// Objective-C bridge for the case-insensitive header lookup. Objective-C can't call the Swift
/// `HTTPURLResponse` extension method above, so this thin static wrapper exposes it. We can't call
/// `-[NSHTTPURLResponse valueForHTTPHeaderField:]` from Objective-C directly because it isn't
/// available before macOS 10.15.
@objc(SentryHTTPHeaderReader) @_spi(Private)
public final class HTTPHeaderReader: NSObject {

    /// Reads `name` from `response`'s headers case-insensitively. See
    /// `HTTPURLResponse.value(forHTTPHeaderFieldCaseInsensitive:)`.
    @objc(valueForHTTPHeaderFieldCaseInsensitive:inResponse:)
    public static func value(forHTTPHeaderFieldCaseInsensitive name: String, in response: HTTPURLResponse) -> String? {
        response.value(forHTTPHeaderFieldCaseInsensitive: name)
    }
}
