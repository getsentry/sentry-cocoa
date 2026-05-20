@_implementationOnly import Sentry
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

/// API for showing/hiding the in-app feedback widget. iOS only.
@objc(SentryCompatFeedbackAPI)
public final class FeedbackAPI: NSObject {
    internal let wrapped: Sentry.SentryFeedbackAPI

    internal init(_ wrapped: Sentry.SentryFeedbackAPI) {
        self.wrapped = wrapped
        super.init()
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
