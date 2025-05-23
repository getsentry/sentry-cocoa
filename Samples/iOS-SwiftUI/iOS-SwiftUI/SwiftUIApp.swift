import Foundation
import Sentry
import SentrySampleShared
import SwiftUI

@main
struct SwiftUIApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate

    init() {
        SentrySDKWrapper.shared.startSentry()
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
        SentrySDK.feedback.showWidget()
        initializedSentry = true
    }
}
