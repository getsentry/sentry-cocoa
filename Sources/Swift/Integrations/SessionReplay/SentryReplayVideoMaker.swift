#if canImport(UIKit) && !SENTRY_NO_UIKIT
import Foundation
import UIKit

@objc
protocol SentryReplayVideoMaker: NSObjectProtocol {
    func addFrameAsync(
        timestamp: Date,
        viewHiearchy: ViewHierarchyNode,
        redactRegions: [RedactRegion],
        renderedViewImage: UIImage,
        maskedViewImage: UIImage,
        forScreen screen: String?
    )
    func releaseFramesUntil(_ date: Date)
    func createVideoInBackgroundWith(beginning: Date, end: Date, completion: @escaping ([SentryVideoInfo]) -> Void)
    func createVideoWith(beginning: Date, end: Date) -> [SentryVideoInfo]
}

extension SentryReplayVideoMaker {
    func addFrameAsync(
        timestamp: Date,
        viewHiearchy: ViewHierarchyNode,
        redactRegions: [RedactRegion],
        renderedViewImage: UIImage,
        maskedViewImage: UIImage,
        forScreen screen: String?
    ) {
        self.addFrameAsync(
            timestamp: timestamp,
            viewHiearchy: viewHiearchy,
            redactRegions: redactRegions,
            renderedViewImage: renderedViewImage,
            maskedViewImage: maskedViewImage,
            forScreen: screen
        )
    }
}

#endif
