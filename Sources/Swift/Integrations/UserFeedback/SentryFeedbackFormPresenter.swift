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
        guard let application = SentryDependencyContainer.sharedInstance().application() else {
            return nil
        }
        guard let viewControllers = application.internal_relevantViewControllers(windowFilter: canPresentFromWindow(_:)) else {
            return nil
        }

        return viewControllers.first(where: canPresentFromController(_:))
    }

    private static func canPresentFromWindow(_ window: UIWindow) -> Bool {
        guard let role = window.windowScene?.session.role.rawValue else {
            return true
        }

        // Compare raw values to avoid availability/deprecation warnings while supporting both
        // UIWindowSceneSessionRoleExternalDisplayNonInteractive and its deprecated predecessor.
        return role != "UIWindowSceneSessionRoleExternalDisplay"
            && role != "UIWindowSceneSessionRoleExternalDisplayNonInteractive"
    }

    private static func canPresentFromController(_ viewController: UIViewController) -> Bool {
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
