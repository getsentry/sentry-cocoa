import Foundation

@objcMembers
public class SentryVideoInfo: NSObject {
    
    public let path: URL
    public let height: Int
    public let width: Int
    public let duration: TimeInterval
    public let frameCount: Int
    public let frameRate: Int
    public let start: Date
    public let end: Date
    public let fileSize: Int
    public let screens: [String]
    
    public init(path: URL, height: Int, width: Int, duration: TimeInterval, frameCount: Int, frameRate: Int, start: Date, end: Date, fileSize: Int, screens: [String]) {
        self.height = height
        self.width = width
        self.duration = duration
        self.frameCount = frameCount
        self.frameRate = frameRate
        self.start = start
        self.end = end
        self.path = path
        self.fileSize = fileSize
        self.screens = screens
    }
    
}
