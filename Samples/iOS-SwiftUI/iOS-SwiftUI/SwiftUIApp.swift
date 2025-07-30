import Foundation
import Sentry
import SentrySampleShared
import SentrySwiftUI
import SwiftUI

@main
struct SwiftUIApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: MyAppDelegate

    init() {
        SentrySDKWrapper.shared.startSentry()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            _ = checkBody()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct MyCustomView: View {
    var body: some View {
        SentryTracedView("Hey Phil") {
            Text("Hey Phil")
        }
    }
}

private let view = MyCustomView()

func checkBody() -> some View {
    if view.body != nil {
        print("The body is not nil")
    }
    return view
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
        guard UIApplication.shared.connectedScenes.first as? UIWindowScene != nil else {
            preconditionFailure("The test app should always have a UIWindowScene at this point")
        }

        SampleAppDebugMenu.shared.display()
        SentrySDK.feedback.showWidget()
        initializedSentry = true
    }
}
