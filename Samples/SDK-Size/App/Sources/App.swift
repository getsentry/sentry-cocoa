import Foundation
import Sentry
import SwiftUI

@main
struct SwiftUIApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate

    init() {
        let options = Options()
        options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
        SentrySDK.start(options: options)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class MyAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = MySceneDelegate.self
        }
        return configuration
    }
}

class MySceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var initializedSentry = false
    func sceneDidBecomeActive(_ scene: UIScene) {
        guard !initializedSentry else { return }
        initializedSentry = true
    }
}
