import SentrySampleShared
import UIKit

// swiftlint:disable unused_optional_binding
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Mirror the scene window to AppDelegate.window for shared sample helpers.
    var window: UIWindow? {
        didSet {
            (UIApplication.shared.delegate as? AppDelegate)?.window = window
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        SampleAppDebugMenu.shared.display()
    }
}
