// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc(SentryObjCFeedbackApi) public final class SentryObjCFeedbackApi: NSObject {
    internal let wrapped: SentryFeedbackAPI

    internal init(_ wrapped: SentryFeedbackAPI) {
        self.wrapped = wrapped
    }

    @available(iOSApplicationExtension, unavailable)
    @objc public func show() {
        wrapped.show()
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(showWithScreenshot:)
    public func show(screenshot: UIImage?) {
        wrapped.show(screenshot: screenshot)
    }

    @available(iOSApplicationExtension, unavailable)
    @objc public func formViewController() -> UIViewController {
        SentryUserFeedbackFormController(screenshot: nil)
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(formViewControllerWithScreenshot:)
    public func formViewController(screenshot: UIImage?) -> UIViewController {
        SentryUserFeedbackFormController(screenshot: screenshot)
    }

    @available(iOSApplicationExtension, unavailable)
    @objc public func showWidget() {
        wrapped.showWidget()
    }

    @available(iOSApplicationExtension, unavailable)
    @objc public func hideWidget() {
        wrapped.hideWidget()
    }
}
#endif
import Foundation

// swiftlint:enable missing_docs
