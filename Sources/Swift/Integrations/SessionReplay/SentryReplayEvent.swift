// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryReplayEvent: Event {
    
    // Start time of the replay segment
    public let replayStartTimestamp: Date
    
    // The Type of the replay
    public let replayType: SentryReplayType
    
    /**
     * Number of the segment in the replay.
     * This is an incremental number
     */
    public let segmentId: Int
 
    /**
     * This will be used to store the name of the screens
     * that appear during the duration of the replay segment.
     */
    public var urls: [String]?

    /**
     * Trace IDs collected during the duration of the replay segment.
     *
     * Populated from traces captured natively while the segment recorded and from
     * IDs registered by hybrid SDKs via `SentrySDK.internal.replay.registerTraceId(_:)`.
     * Serialized under `trace_ids` as 32-character hexadecimal strings.
     */
    public var traceIds: [SentryId]?

    public init(eventId: SentryId, replayStartTimestamp: Date, replayType: SentryReplayType, segmentId: Int) {
        self.replayStartTimestamp = replayStartTimestamp
        self.replayType = replayType
        self.segmentId = segmentId
        
        super.init()
        self.eventId = eventId
        self.type = "replay_video"
    }
    
    required convenience init() {
        fatalError("init() has not been implemented")
    }
    
    @_spi(Private) public override func serialize() -> [String: Any] {
        var result = super.serialize()
        result["urls"] = urls
        // Omit `trace_ids` entirely when empty; the buffer is left nil for segments without traces.
        if let traceIds = traceIds, !traceIds.isEmpty {
            result["trace_ids"] = traceIds.map { $0.sentryIdString }
        }
        result["replay_start_timestamp"] = replayStartTimestamp.timeIntervalSince1970
        result["replay_id"] = self.eventId.sentryIdString
        result["segment_id"] = segmentId
        result["replay_type"] = replayType.toString()
        return result
    }
}
// swiftlint:enable missing_docs
