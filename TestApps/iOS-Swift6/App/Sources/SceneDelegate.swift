import SentrySampleShared
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // UIKit initializes this window from the scene storyboard.
    var window: UIWindow?
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        SampleAppDebugMenu.shared.display(in: windowScene)
    }
}
