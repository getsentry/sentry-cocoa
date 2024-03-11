import Foundation

@objcMembers
class SentryVideoInfo: NSObject {
    
    let height: Int
    let width: Int
    let duration: TimeInterval
    let frameCount: Int
    let frameRate: Int
    let start: Date
    let end: Date
    
    init(height: Int, width: Int, duration: TimeInterval, frameCount: Int, frameRate: Int, start: Date, end: Date) {
        self.height = height
        self.width = width
        self.duration = duration
        self.frameCount = frameCount
        self.frameRate = frameRate
        self.start = start
        self.end = end
    }
    
}
