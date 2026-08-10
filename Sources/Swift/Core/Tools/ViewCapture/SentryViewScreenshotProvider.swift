// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
import Foundation
import UIKit

@_spi(Private) public typealias ScreenshotCallback = (_ maskedViewImage: UIImage) -> Void

/// Reports the masked screenshot plus the main-thread capture cost used for Session Replay pacing.
///
/// `mainThreadDuration` covers only the work that blocks the main thread (for example redaction
/// traversal and view rendering). Async post-processing such as mask compositing is excluded so
/// adaptive backoff does not treat off-main work as UI cost.
@_spi(Private) public typealias TimedScreenshotCallback = (_ maskedViewImage: UIImage, _ mainThreadDuration: TimeInterval) -> Void

@objc
@_spi(Private) public protocol SentryViewScreenshotProvider: NSObjectProtocol {
    func image(view: UIView, onComplete: @escaping ScreenshotCallback)
}

/// Optional screenshot provider that can report main-thread capture duration for pacing decisions.
///
/// Custom hybrid providers may keep implementing only ``SentryViewScreenshotProvider``. Session Replay
/// then falls back to wall-clock timing around the full provider callback.
@_spi(Private) public protocol SentryTimedViewScreenshotProvider: SentryViewScreenshotProvider {
    func image(view: UIView, onComplete: @escaping TimedScreenshotCallback)
}
#endif
#endif
// swiftlint:enable missing_docs
