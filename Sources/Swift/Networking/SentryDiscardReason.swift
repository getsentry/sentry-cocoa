// swiftlint:disable missing_docs
import Foundation

/**
 * A reason that defines why events were lost, see
 * https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload.
 */
@objc(SentryDiscardReason) @_spi(Private)
public enum SentryDiscardReason: UInt {
    case beforeSend = 0
    case eventProcessor = 1
    case sampleRate = 2
    case networkError = 3
    case queueOverflow = 4
    case cacheOverflow = 5
    case rateLimitBackoff = 6
    case insufficientData = 7
    case sendError = 8
}
// swiftlint:enable missing_docs
