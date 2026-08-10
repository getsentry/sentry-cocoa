// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
import Foundation
import UIKit

/// Reports the masked screenshot and timing data for each capture phase.
@_spi(Private) public typealias ScreenshotCallback = (_ maskedViewImage: UIImage, _ metadata: SentryViewPhotographerScreenshotMetadata) -> Void

@objc
@_spi(Private) public protocol SentryViewScreenshotProvider: NSObjectProtocol {
    func image(view: UIView, onComplete: @escaping ScreenshotCallback)
}
#endif
#endif
// swiftlint:enable missing_docs
