import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Mirror the scene window to AppDelegate.window for shared sample helpers.
    var window: UIWindow? {
        didSet {
            (UIApplication.shared.delegate as? AppDelegate)?.window = window
        }
    }
}
