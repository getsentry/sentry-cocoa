// swiftlint:disable missing_docs
import Foundation
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOSApplicationExtension, unavailable)
enum SentryFeedbackFormPresenter {
    /// Finds a view controller suitable for automatic presentation by using the key
    /// window in a foreground-active scene.
    static func presentingViewController() -> UIViewController? {
        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes
            where windowScene.activationState == .foregroundActive {
            if let viewController = keyWindowViewController(
                in: windowScene,
                resolving: { window in topMostPresentedViewController(from: window.rootViewController) }
            ) {
                return viewController
            }
        }

        return nil
    }

    /// Finds the view controller that should present the feedback form for the key window in
    /// the given scene.
    private static func keyWindowViewController(
        in windowScene: UIWindowScene,
        resolving resolveViewController: (UIWindow) -> UIViewController?
    ) -> UIViewController? {
        for window in windowScene.windows where window.isKeyWindow {
            guard let viewController = resolveViewController(window) else {
                continue
            }
            return viewController
        }
        return nil
    }

    /// Resolves the view controller best suited for presenting the feedback form by walking
    /// through any view controllers already presented by the starting view controller.
    private static func topMostPresentedViewController(from viewController: UIViewController?) -> UIViewController? {
        var currentViewController = viewController
        while let presentedViewController = currentViewController?.presentedViewController {
            currentViewController = presentedViewController
        }

        guard currentViewController?.isBeingDismissed != true else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is being dismissed")
            return nil
        }

        guard currentViewController?.isBeingPresented != true else {
            SentrySDKLog.debug("Cannot show feedback form — presenter is being presented")
            return nil
        }

        return currentViewController
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
