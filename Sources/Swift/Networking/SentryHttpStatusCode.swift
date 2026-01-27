import Foundation

/// HTTP status codes used by the Sentry SDK.
/// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
@_spi(Private) @objc(SentryHttpStatusCode)
public enum SentryHttpStatusCode: Int {

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/200
    case ok = 200

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/201
    case created = 201

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400
    case badRequest = 400

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/412
    case preconditionFailed = 412

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/413
    case contentTooLarge = 413

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429
    case tooManyRequests = 429

    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/500
    case internalServerError = 500
}

/// Enables direct comparison between Int and SentryHttpStatusCode.
/// Allows writing `statusCode == SentryHttpStatusCode.contentTooLarge` instead of `statusCode == SentryHttpStatusCode.contentTooLarge.rawValue`.
/// Note: This operator is only needed for Swift. In Objective-C, you can already compare the enum directly to an int without .rawValue.
func == (lhs: Int, rhs: SentryHttpStatusCode) -> Bool {
    return lhs == rhs.rawValue
}

/// Enables direct comparison between SentryHttpStatusCode and Int.
/// Allows writing `SentryHttpStatusCode.contentTooLarge == statusCode` instead of `SentryHttpStatusCode.contentTooLarge.rawValue == statusCode`.
/// Note: This operator is only needed for Swift. In Objective-C, you can already compare the enum directly to an int without .rawValue.
func == (lhs: SentryHttpStatusCode, rhs: Int) -> Bool {
    return lhs.rawValue == rhs
}
