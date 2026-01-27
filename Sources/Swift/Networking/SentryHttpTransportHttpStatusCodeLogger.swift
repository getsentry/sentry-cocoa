@_implementationOnly import _SentryPrivate
import Foundation

/// Logs error messages for HTTP transport failures.
/// See https://develop.sentry.dev/sdk/expected-features/#dealing-with-network-failures
@_spi(Private) @objc(SentryHttpTransportHttpStatusCodeLogger)
public final class SentryHttpTransportHttpStatusCodeLogger: NSObject {

    /// Logs an error if the HTTP status code requires specific error messaging.
    /// Currently handles HTTP 413 (Content Too Large) by logging envelope size and item types.
    @objc
    public static func logHttpResponseError(
        statusCode: Int,
        envelope: SentryEnvelope,
        request: URLRequest
    ) {
        guard statusCode == SentryHttpStatusCode.contentTooLarge else {
            // We don't log here, because this would log for almost every request.
            return
        }

        let sizeInBytes = request.httpBody?.count ?? 0
        let itemTypes: [String] = envelope.items.map { $0.header.type }
        let typesString = itemTypes.joined(separator: ", ")

        let message = "Upstream returned HTTP 413 Content Too Large. This is due to the envelope containing item types ( \(typesString) ) exceeding the allowed size limit. The envelope size in bytes (compressed): \(sizeInBytes)"
        SentrySDKLog.error(message)
    }
}
