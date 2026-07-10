#if !os(macOS) && !os(watchOS)
import UIKit

@objcMembers
public final class SampleAppUI: NSObject {
    public static var activeWindow: UIWindow? {
        let activeWindowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        return activeWindowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    public static var activeViewController: UIViewController? {
        presentingViewController(in: activeWindow)
    }

    public static func presentingViewController(in window: UIWindow?) -> UIViewController? {
        guard let rootViewController = window?.rootViewController else { return nil }
        return presentingViewController(from: rootViewController)
    }

    private static func presentingViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return presentingViewController(from: presentedViewController)
        }
        if let navigationController = viewController as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return presentingViewController(from: visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return presentingViewController(from: selectedViewController)
        }
        if let splitViewController = viewController as? UISplitViewController,
           let lastViewController = splitViewController.viewControllers.last {
            return presentingViewController(from: lastViewController)
        }
        return viewController
    }
}
#endif // !os(macOS) && !os(watchOS)
