#if canImport(UIKit) && !SENTRY_NO_UIKIT
import Foundation
import UIKit

typealias ScreenshotCallback = (UIImage) -> Void

@objc
protocol SentryViewScreenshotProvider: NSObjectProtocol {
    func image(view: UIView, options: SentryRedactOptions, onComplete: @escaping ScreenshotCallback)
}
#endif
