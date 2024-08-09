import Foundation

@objcMembers
class SentryFramesDelayResult: NSObject {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    let delayDuration: CFTimeInterval
    /// The system time stamp of the last rendered frame
    let lastFrameSystemTimeStamp: UInt64
    
    init(delayDuration: CFTimeInterval, lastFrameSystemTimeStamp: UInt64) {
        self.delayDuration = delayDuration
        self.lastFrameSystemTimeStamp = lastFrameSystemTimeStamp
    }
}
