#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// Returns the given view controller together with all of its descendants —
/// children, grandchildren, ... — flattened into a single array.
func viewControllerHierarchy(of viewController: UIViewController) -> [UIViewController] {
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
#endif
