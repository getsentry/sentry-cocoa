@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryReplayRecording: NSObject {
    
    static let SentryReplayEncoding = "h264"
    static let SentryReplayContainer = "mp4"
    static let SentryReplayFrameRateType = "constant"
    
    let segmentId: Int

    let meta: SentryRRWebMetaEvent
    let video: SentryRRWebVideoEvent
    
    init(segmentId: Int, size: Int, start: Date, duration: TimeInterval, frameCount: Int, frameRate: Int, height: Int, width: Int) {
        self.segmentId = segmentId
        
        meta = SentryRRWebMetaEvent(timestamp: start, height: height, width: width)
        video = SentryRRWebVideoEvent(timestamp: start, segmentId: segmentId, size: size, duration: duration, encoding: SentryReplayRecording.SentryReplayEncoding, container: SentryReplayRecording.SentryReplayContainer, height: height, width: width, frameCount: frameCount, frameRateType: SentryReplayRecording.SentryReplayFrameRateType, frameRate: frameRate, left: 0, top: 0)
    }

    func headerForReplayRecording() -> [String: Any] {
        return ["segment_id": segmentId]
    }

    func serialize() -> [[String: Any]] {
        let metaInfo = meta.serialize()

        let recordingInfo = video.serialize()

        return [metaInfo, recordingInfo]
    }
}
