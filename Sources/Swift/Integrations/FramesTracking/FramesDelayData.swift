import Foundation

@objcMembers
class SentryFramesDelayResult: NSObject {
    /// The frames delay for the passed time period. If frame delay can't be calculated this is -1.
    let delayDuration: CFTimeInterval
    /// The system time stamp of the last rendered frame
    let framesCount: UInt
    
    init(delayDuration: CFTimeInterval, framesCount: UInt) {
        self.delayDuration = delayDuration
        self.framesCount = framesCount
    }
}
