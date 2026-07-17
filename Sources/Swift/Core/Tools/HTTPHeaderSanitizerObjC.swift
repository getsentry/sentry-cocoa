#if SDK_V10
import Foundation

/// Objective-C facade for HTTP header and cookie sanitization.
@_spi(Private) @objcMembers public final class HTTPHeaderSanitizerObjC: NSObject {
    /// Sanitizes request or response headers using the configured data collection options.
    @_spi(Private) @objc(sanitizeHeaders:options:isRequest:)
    public static func sanitizeHeaders(
        _ headers: [String: String],
        options: SentryDataCollectionObjCOptions,
        isRequest: Bool
    ) -> HTTPHeaderSanitizationResultObjC {
        HTTPHeaderSanitizationResultObjC(
            HTTPHeaderSanitizer.sanitizeHeaders(
                headers,
                options: options.wrapped,
                isRequest: isRequest
            )
        )
    }
}
#endif // SDK_V10
