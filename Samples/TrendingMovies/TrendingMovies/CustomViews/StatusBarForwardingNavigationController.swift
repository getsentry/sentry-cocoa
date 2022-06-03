import UIKit

/// A navigation controller that forwards requests for status bar hidden state
/// and style to its child view controllers.
class StatusBarForwardingNavigationController: UINavigationController, UINavigationControllerDelegate {
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        delegate = self
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        delegate = self
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    override var childForStatusBarHidden: UIViewController? {
        topViewController
    }

    // MARK: UINavigationControllerDelegate

    func navigationController(_: UINavigationController, willShow _: UIViewController, animated _: Bool) {
        setNeedsStatusBarAppearanceUpdate()
    }
}
