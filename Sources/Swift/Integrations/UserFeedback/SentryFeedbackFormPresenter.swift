// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension, unavailable)
enum SentryFeedbackFormPresenter {
    /// Finds a view controller suitable for automatic presentation by reusing the SDK's
    /// active-window and relevant-view-controller lookup.
    static func presentingViewController() -> UIViewController? {
        guard let viewControllers = SentryDependencyContainer.sharedInstance().application()?.internal_relevantViewControllers() else {
            return nil
        }

        return viewControllers.first(where: canPresentForm(from:))
    }

    private static func canPresentForm(from viewController: UIViewController) -> Bool {
        guard viewController.presentedViewController == nil else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is already presenting another view controller")
            return false
        }

        guard !viewController.isBeingDismissed else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is being dismissed")
            return false
        }

        guard !viewController.isBeingPresented else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is being presented")
            return false
        }

        return true
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
