// swiftlint:disable missing_docs
import Foundation

/**
 * The data category rate limits: https://develop.sentry.dev/sdk/rate-limiting/#definitions and
 * client reports: https://develop.sentry.dev/sdk/client-reports/#envelope-item-payload. Be aware
 * that these categories are different from the envelope item types.
 */
@objc(SentryDataCategory) @_spi(Private)
public enum SentryDataCategory: UInt, CaseIterable {
    case all
    case `default`
    case error
    case session
    case transaction
    case attachment
    case userFeedback
    case profile
    case metricBucket
    case replay
    case profileChunkUI
    case span
    case feedback
    case logItem
    case traceMetric
    case logByte
    case traceMetricByte
    case unknown

    // While these data category names might look similar to the envelope item types, they are not
    // identical, and have slight differences. Just open them side by side and you'll see the
    // differences.
    public var name: String {
        switch self {
        case .all: return ""
        case .default: return "default"
        case .error: return "error"
        case .session: return "session"
        case .transaction: return "transaction"
        case .attachment: return "attachment"
        case .profile: return "profile"
        case .profileChunkUI: return "profile_chunk_ui"
        case .replay: return "replay"
        case .metricBucket: return "metric_bucket"
        case .span: return "span"
        case .feedback: return "feedback"
        case .logItem: return "log_item"
        case .logByte: return "log_byte"
        case .traceMetric: return "trace_metric"
        case .traceMetricByte: return "trace_metric_byte"
        // userFeedback is unused, so it has no name and maps to "unknown".
        case .userFeedback, .unknown: return "unknown"
        }
    }

    public init(name: String) {
        // The reverse of `name`. `userFeedback` and `unknown` share the "unknown" name, so an
        // unknown string maps to `.unknown`.
        let match = SentryDataCategory.allCases.first { $0 != .userFeedback && $0.name == name }
        self = match ?? .unknown
    }
}

/// Objective-C compatible mapper for `SentryDataCategory`, replacing the former
/// `SentryDataCategoryMapper` free functions. Swift callers should prefer the enum's own
/// `name`/`init(itemType:)`/`init(name:)` API.
@objc(SentryDataCategoryMapper) @_spi(Private)
public final class SentryDataCategoryMapper: NSObject {
    @objc public static func name(for category: SentryDataCategory) -> String {
        category.name
    }

    @objc public static func category(forEnvelopeItemType itemType: String) -> SentryDataCategory {
        SentryDataCategory(itemType: itemType)
    }
}
// swiftlint:enable missing_docs
