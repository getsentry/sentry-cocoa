import Foundation

@objcMembers
class SentryVideoInfo: NSObject {
    
    let height: Int
    let width: Int
    let duration: TimeInterval
    let frameCount: Int
    let frameRate: Int
    
    init(height: Int, width: Int, duration: TimeInterval, frameCount: Int, frameRate: Int) {
        self.height = height
        self.width = width
        self.duration = duration
        self.frameCount = frameCount
        self.frameRate = frameRate
    }
    
}
