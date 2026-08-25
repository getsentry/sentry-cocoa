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

    public var name: String {
        switch self {
        case .beforeSend: return "before_send"
        case .eventProcessor: return "event_processor"
        case .sampleRate: return "sample_rate"
        case .networkError: return "network_error"
        case .queueOverflow: return "queue_overflow"
        case .cacheOverflow: return "cache_overflow"
        case .rateLimitBackoff: return "ratelimit_backoff"
        case .insufficientData: return "insufficient_data"
        case .sendError: return "send_error"
        }
    }
}

@objcMembers
@_spi(Private) public class SentryDiscardReasonMapper: NSObject {
    public static func nameFor(_ reason: SentryDiscardReason) -> String {
        return reason.name
    }
}
// swiftlint:enable missing_docs
