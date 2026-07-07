import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Mirror the scene window to AppDelegate.window for shared sample helpers.
    var window: UIWindow? {
        didSet {
            (UIApplication.shared.delegate as? AppDelegate)?.window = window
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }
}
