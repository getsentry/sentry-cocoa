import SentrySampleShared
import UIKit

// swiftlint:disable unused_optional_binding
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        SampleAppDebugMenu.shared.display()
    }
}
