@_implementationOnly import _SentryPrivate
import Foundation

/// Logs error messages for HTTP transport failures.
/// See https://develop.sentry.dev/sdk/expected-features/#dealing-with-network-failures
@_spi(Private) @objc(SentryHttpTransportErrorLogger)
public final class SentryHttpTransportErrorLogger: NSObject {

    /// Logs an error if the HTTP status code requires specific error messaging.
    /// Currently handles HTTP 413 (Content Too Large) by logging envelope size and item types.
    @objc
    public static func logHttpResponseError(
        statusCode: Int,
        envelope: SentryEnvelope,
        request: URLRequest
    ) {
        guard statusCode == 413 else {
            // We log here, because this would log for almost every request, creating unnecessary noise.
            return
        }

        let sizeInBytes = request.httpBody?.count ?? 0
        let itemTypes: [String] = envelope.items.map { $0.header.type }
        let typesString = itemTypes.joined(separator: ", ")

        let message = "Envelope discarded due to size limit. Size: \(sizeInBytes) bytes (compressed), item types: \(typesString)"
        SentrySDKLog.error(message)
    }
}
