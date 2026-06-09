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
    @objc(showWithConfigure:)
    public func show(configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?) {
        wrapped.show(configure: wrappedConfigure(configure))
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(showWithScreenshot:configure:)
    public func show(screenshot: UIImage?, configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?) {
        wrapped.show(screenshot: screenshot, configure: wrappedConfigure(configure))
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
    @objc(formViewControllerWithConfigure:)
    public func formViewController(configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?) -> UIViewController {
        SentryUserFeedbackFormController(configure: wrappedConfigure(configure))
    }

    @available(iOSApplicationExtension, unavailable)
    @objc(formViewControllerWithScreenshot:configure:)
    public func formViewController(
        screenshot: UIImage?,
        configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?
    ) -> UIViewController {
        SentryUserFeedbackFormController(screenshot: screenshot, configure: wrappedConfigure(configure))
    }

    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10.")
    @objc public func showWidget() {
        wrapped.showWidget()
    }

    @available(iOSApplicationExtension, unavailable)
    @available(*, deprecated, message: "The Sentry-managed User Feedback widget is deprecated and will be removed in v10.")
    @objc public func hideWidget() {
        wrapped.hideWidget()
    }

    private func wrappedConfigure(
        _ configure: ((SentryObjCUserFeedbackConfiguration) -> Void)?
    ) -> SentryUserFeedbackConfigurationCallback? {
        guard let configure = configure else { return nil }
        return { configuration in
            configure(SentryObjCUserFeedbackConfiguration(configuration))
        }
    }
}
#endif

// swiftlint:enable missing_docs
