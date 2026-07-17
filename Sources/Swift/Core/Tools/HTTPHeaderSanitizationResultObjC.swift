#if SDK_V10
import Foundation

/// Objective-C wrapper for the result of sanitizing HTTP headers and cookies.
@_spi(Private) @objcMembers public final class HTTPHeaderSanitizationResultObjC: NSObject {
    let wrapped: HTTPHeaderSanitizer.SanitizedHeaders

    /// Sanitized non-cookie HTTP headers.
    public var headers: [String: String] {
        wrapped.headers
    }

    /// Parsed and sanitized cookie names and values.
    public var cookies: [String: String] {
        wrapped.cookies
    }

    init(_ wrapped: HTTPHeaderSanitizer.SanitizedHeaders) {
        self.wrapped = wrapped
    }
}
#endif // SDK_V10
