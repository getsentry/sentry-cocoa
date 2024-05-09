@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryRRWebVideoEvent: SentryRRWebCustomEvent {
    init(timestamp: Date, segmentId: Int, size: Int, duration: TimeInterval, encoding: String, container: String, height: Int, width: Int, frameCount: Int, frameRateType: String, frameRate: Int, left: Int, top: Int) {
        
        super.init(timestamp: timestamp, tag: "video", payload: [
            "timestamp": SentryDateUtil.millisecondsSince1970(timestamp),
            "segmentId": segmentId,
            "size": size,
            "duration": duration,
            "encoding": encoding,
            "container": container,
            "height": height,
            "width": width,
            "frameCount": frameCount,
            "frameRateType": frameRateType,
            "frameRate": frameRate,
            "left": left,
            "top": top
        ])
    }
}
