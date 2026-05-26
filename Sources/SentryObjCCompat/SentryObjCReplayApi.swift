// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
import UIKit

public final class SentryObjCReplayApi: NSObject {
    internal let wrapped: SentryReplayApi

    internal init(_ wrapped: SentryReplayApi) {
        self.wrapped = wrapped
    }

    @objc public func maskView(_ view: UIView) {
        wrapped.maskView(view)
    }

    @objc public func unmaskView(_ view: UIView) {
        wrapped.unmaskView(view)
    }

    @objc public func pause() {
        wrapped.pause()
    }

    @objc public func resume() {
        wrapped.resume()
    }

    @objc public func start() {
        wrapped.start()
    }

    @objc public func stop() {
        wrapped.stop()
    }

    @objc public func showMaskPreview() {
        wrapped.showMaskPreview()
    }

    @objc public func showMaskPreview(_ opacity: CGFloat) {
        wrapped.showMaskPreview(opacity)
    }

    @objc public func hideMaskPreview() {
        wrapped.hideMaskPreview()
    }
}
#endif
import Foundation

// swiftlint:enable missing_docs
