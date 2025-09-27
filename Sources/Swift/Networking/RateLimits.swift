import Foundation

/**
 * Parses HTTP responses from the Sentry server for rate limits.
 *
 * When a rate limit is reached, the SDK should stop data transmission
 * until the rate limit has expired.
 */
@objc(SentryRateLimits)
public protocol RateLimits: NSObjectProtocol {

    /**
     * Check if a data category has reached a rate limit.
     *
     * - Parameter category: the type e.g. event, error, session, transaction, etc.
     * - Returns: `true` if limit is reached, `false` otherwise.
     */
    @objc func isRateLimitActive(_ category: UInt) -> Bool

    /**
     * Should be called for each HTTP response of the Sentry server. It checks the response for any
     * communicated rate limits.
     *
     * - Parameter response: The response from the server
     */
    @objc func update(_ response: HTTPURLResponse)
}
