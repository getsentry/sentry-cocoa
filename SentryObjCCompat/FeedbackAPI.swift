internal import SentrySwift
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

/// API for showing/hiding the in-app feedback widget. iOS only.
@objc(SOCSentryFeedbackAPI)
public final class FeedbackAPI: NSObject {
    internal let wrapped: SentrySwift.SentryFeedbackAPI

    internal init(_ wrapped: SentrySwift.SentryFeedbackAPI) {
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
