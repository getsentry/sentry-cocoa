// swiftlint:disable missing_docs
/// Each item type must have a data category name mapped to it; see SentryDataCategoryMapper
///
/// While these envelope item types might look similar to the data categories,
/// they are not identical, and have slight differences.
@_spi(Private) @objcMembers public final class SentryEnvelopeItemTypes: NSObject {
    public static let event = "event"
    public static let session = "session"
    public static let feedback = "feedback"
    public static let transaction = "transaction"
    public static let attachment = "attachment"
    public static let clientReport = "client_report"
    public static let profile = "profile"
    public static let replayVideo = "replay_video"
    public static let statsd = "statsd"
    public static let profileChunk = "profile_chunk"
    public static let log = "log"
}
// swiftlint:enable missing_docs
