#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import UIKit

typealias ScreenshotCallback = (_ viewHierarchy: SentryViewHierarchyNode, _ redactRegions: [SentryRedactRegion], _ renderedViewImage: UIImage, _ maskedViewImage: UIImage) -> Void

@objc
protocol SentryViewScreenshotProvider: NSObjectProtocol {
    func image(view: UIView, onComplete: @escaping ScreenshotCallback)
}
#endif
#endif
