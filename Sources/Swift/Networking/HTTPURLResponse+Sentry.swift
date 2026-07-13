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

    /// Objective-C-callable wrapper around `value(forHTTPHeaderFieldCaseInsensitive:)`, so
    /// Objective-C call sites (e.g. `SentryNetworkTracker`) route header lookups through the same
    /// sanctioned, case-insensitive helper, including the pre-macOS-10.15 fallback. We can't call
    /// `-[NSHTTPURLResponse valueForHTTPHeaderField:]` directly because it isn't available before
    /// macOS 10.15.
    @objc(sentryValueForHTTPHeaderFieldCaseInsensitive:)
    @_spi(Private) public func sentryValue(forHTTPHeaderFieldCaseInsensitive name: String) -> String? {
        value(forHTTPHeaderFieldCaseInsensitive: name)
    }

    /// Pre-macOS-10.15 fallback is an extra method so it can be unit tested. We plan on bumping to macOS 12
    /// in August 2026, so we don't use this implementation for all platforms.
    ///
    /// `allHeaderFields` subscripting is case-sensitive, so we scan all keys and compare them
    /// case-insensitively against `name`. This is O(n), which is acceptable for the small number of
    /// response headers.
    func sentryCaseInsensitiveHeaderValue(forName name: String) -> String? {
        let lowercasedName = name.lowercased()
        for (key, value) in allHeaderFields {
            if let key = key as? String, key.lowercased() == lowercasedName {
                return value as? String
            }
        }
        return nil
    }
}
