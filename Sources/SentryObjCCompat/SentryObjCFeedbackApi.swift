// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

@objc(SentryObjCFeedbackApi) public final class SentryObjCFeedbackApi: NSObject {
    internal let wrapped: SentryFeedbackAPI

    internal init(_ wrapped: SentryFeedbackAPI) {
        self.wrapped = wrapped
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
}
#endif
import Foundation

// swiftlint:enable missing_docs
