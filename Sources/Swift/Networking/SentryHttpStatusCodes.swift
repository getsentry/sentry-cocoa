import Foundation

/// HTTP status codes used by the Sentry SDK.
/// See https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
@_spi(Private) @objc(SentryHttpStatusCodes)
public enum SentryHttpStatusCodes: Int {
    /// HTTP 200 OK
    /// Indicates that the request succeeded.
    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/200
    case ok = 200

    /// HTTP 412 Precondition Failed
    /// Indicates that access to the resource has been denied.
    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/412
    case preconditionFailed = 412

    /// HTTP 413 Content Too Large
    /// Indicates that the request entity is larger than limits defined by server.
    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/413
    case contentTooLarge = 413

    /// HTTP 429 Too Many Requests
    /// Indicates the user has sent too many requests in a given amount of time.
    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429
    case tooManyRequests = 429

    /// HTTP 500 Internal Server Error
    /// Indicates that the server encountered an unexpected condition.
    /// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/500
    case internalServerError = 500
}

/// Enables direct comparison between Int and SentryHttpStatusCodes.
/// Allows writing `statusCode == SentryHttpStatusCodes.contentTooLarge` instead of `statusCode == SentryHttpStatusCodes.contentTooLarge.rawValue`.
@_spi(Private)
public func == (lhs: Int, rhs: SentryHttpStatusCodes) -> Bool {
    return lhs == rhs.rawValue
}

/// Enables direct comparison between SentryHttpStatusCodes and Int.
/// Allows writing `SentryHttpStatusCodes.contentTooLarge == statusCode` instead of `SentryHttpStatusCodes.contentTooLarge.rawValue == statusCode`.
@_spi(Private)
public func == (lhs: SentryHttpStatusCodes, rhs: Int) -> Bool {
    return lhs.rawValue == rhs
}
