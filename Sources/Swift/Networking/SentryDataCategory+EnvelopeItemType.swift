// swiftlint:disable missing_docs
import Foundation

extension SentryDataCategory {
    /// Maps an envelope item type to its data category. Kept out of the core enum because it
    /// couples `SentryDataCategory` to `SentryEnvelopeItemTypes`, which is a different domain.
    // swiftlint:disable:next cyclomatic_complexity
    public init(itemType: String) {
        switch itemType {
        case SentryEnvelopeItemTypes.event: self = .error
        case SentryEnvelopeItemTypes.session: self = .session
        case SentryEnvelopeItemTypes.transaction: self = .transaction
        case SentryEnvelopeItemTypes.attachment: self = .attachment
        case SentryEnvelopeItemTypes.profile: self = .profile
        // Relay infers the data category for a profile chunk from its platform, and UI platforms
        // (cocoa, android, javascript) map to "profile_chunk_ui" rather than "profile_chunk". As
        // Cocoa only sends UI profile chunks, we always use the UI category, so we honor the
        // server's rate limits and emit client reports under the correct category. See Relay's data
        // categories:
        // https://github.com/getsentry/relay/blob/0561339affbb3a2fd512386f459b3a4775e4e581/relay-base-schema/src/data_category.rs#L175
        case SentryEnvelopeItemTypes.profileChunk: self = .profileChunkUI
        case SentryEnvelopeItemTypes.replayVideo: self = .replay
        case SentryEnvelopeItemTypes.feedback: self = .feedback
        // The envelope item type used for metrics is statsd whereas the client report category for
        // discarded events is metric_bucket.
        case SentryEnvelopeItemTypes.statsd: self = .metricBucket
        case SentryEnvelopeItemTypes.log: self = .logItem
        case SentryEnvelopeItemTypes.traceMetric: self = .traceMetric
        default: self = .default
        }
    }
}
// swiftlint:enable missing_docs
