// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK

public final class SentryObjCFeedbackApi: NSObject {
    internal let wrapped: SentryFeedbackAPI

    internal init(_ wrapped: SentryFeedbackAPI) {
        self.wrapped = wrapped
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
