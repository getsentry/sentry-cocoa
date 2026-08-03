import Foundation

extension HTTPURLResponse {

    /// Reads a header case-insensitively.
    /// Since HTTP/2 HTTP field names are case-insensitive including HTTP headers; see HTTP/2 (RFC 9113, 8.2.1) and HTTP/3 (RFC 9114, 4.2):
    /// - https://www.rfc-editor.org/rfc/rfc9113#section-8.2.1
    /// - https://www.rfc-editor.org/rfc/rfc9114#section-4.2
    func value(forHTTPHeaderFieldCaseInsensitive name: String) -> String? {
        value(forHTTPHeaderField: name)
    }
}

/// Objective-C bridge for the case-insensitive header lookup. Objective-C can't call the Swift
/// `HTTPURLResponse` extension method above, so this thin static wrapper exposes it.
@objc(SentryHTTPHeaderReader) @_spi(Private)
public final class HTTPHeaderReader: NSObject {

    /// Reads `name` from `response`'s headers case-insensitively. See
    /// `HTTPURLResponse.value(forHTTPHeaderFieldCaseInsensitive:)`.
    @objc(valueForHTTPHeaderFieldCaseInsensitive:inResponse:)
    public static func value(forHTTPHeaderFieldCaseInsensitive name: String, in response: HTTPURLResponse) -> String? {
        response.value(forHTTPHeaderFieldCaseInsensitive: name)
    }
}
