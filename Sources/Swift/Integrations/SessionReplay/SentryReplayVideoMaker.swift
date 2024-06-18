#if canImport(UIKit)
import Foundation
import UIKit

@objc
protocol SentryReplayVideoMaker: NSObjectProtocol {
    var videoWidth: Int { get set }
    var videoHeight: Int { get set }
    
    func addFrameAsync(image: UIImage)
    func releaseFramesUntil(_ date: Date)
    func createVideoWith(duration: TimeInterval, beginning: Date, outputFileURL: URL, completion: @escaping (SentryVideoInfo?, Error?) -> Void) throws
}
#endif
