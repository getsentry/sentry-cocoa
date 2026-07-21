#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

enum SentryViewController {
    /// An array of view controllers that are descendants — children, grandchildren, ... —
    /// of the given view controller (including the view controller itself).
    static func descendants(of viewController: UIViewController) -> [UIViewController] {
        // UIViewController guarantees a parent can't be a child of its own child,
        // so the parent/child relationship is acyclic.
        var allViewControllers: [UIViewController] = [viewController]
        var toAdd = viewController.children

        while let last = toAdd.popLast() {
            allViewControllers.append(last)
            toAdd.append(contentsOf: last.children)
        }
        return allViewControllers
    }
}
#endif
