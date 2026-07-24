#if SDK_V10
import Foundation

/// Objective-C facade for HTTP header and cookie sanitization.
@_spi(Private) @objcMembers public final class HTTPHeaderSanitizerObjC: NSObject {
    /// Sanitizes request headers using the configured data collection options.
    @_spi(Private) @objc(sanitizeRequestHeaders:options:)
    public static func sanitizeRequestHeaders(
        _ headers: [String: String],
        options: SentryDataCollectionObjCOptions
    ) -> HTTPHeaderSanitizationResultObjC {
        HTTPHeaderSanitizationResultObjC(
            HTTPHeaderSanitizer.sanitizeRequestHeaders(
                headers,
                options: options.wrapped
            )
        )
    }

    /// Sanitizes response headers using the configured data collection options.
    @_spi(Private) @objc(sanitizeResponseHeaders:options:)
    public static func sanitizeResponseHeaders(
        _ headers: [String: String],
        options: SentryDataCollectionObjCOptions
    ) -> HTTPHeaderSanitizationResultObjC {
        HTTPHeaderSanitizationResultObjC(
            HTTPHeaderSanitizer.sanitizeResponseHeaders(
                headers,
                options: options.wrapped
            )
        )
    }
}
#endif // SDK_V10
