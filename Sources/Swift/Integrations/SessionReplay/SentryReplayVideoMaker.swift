#if canImport(UIKit) && !SENTRY_NO_UIKIT
import Foundation
import UIKit

@objc
protocol SentryReplayVideoMaker: NSObjectProtocol {
    func addFrameAsync(image: UIImage, forScreen: String?) 
    func releaseFramesUntil(_ date: Date)
    func createVideoInBackgroundWith(beginning: Date, end: Date, completion: @escaping ([SentryVideoInfo]) -> Void)
    func createVideoWith(beginning: Date, end: Date) -> [SentryVideoInfo]
}

extension SentryReplayVideoMaker {
    func addFrameAsync(image: UIImage) {
        self.addFrameAsync(image: image, forScreen: nil)
    }
}

#endif
