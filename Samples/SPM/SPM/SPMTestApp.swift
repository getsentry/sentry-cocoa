import SentrySwift
import SwiftUI

@main
struct SPMTestApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: SPMTestAppDelegate

    init() {
        let options = Options()
        options.enableAppHangTracking = true
        options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"

        // Integration: File I/O Tracing
        options.enableDataSwizzling = true
        options.enableFileManagerSwizzling = true

        // Integration: Session Replay
        options.sessionReplay.maskAllImages = false

        // Integration: User Feedback
        options.configureUserFeedback = { _ in
            
        }

        SentrySDK.start(options: options)

        let user = User()
        SentrySDK.setUser(user)

        let breadcrumb = Breadcrumb(level: .error, category: "test")
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class SPMTestAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SPMTestAppSceneDelegate.self
        }
        return configuration
    }
}

class SPMTestAppSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: any UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        guard let keyWindow = windowScene.keyWindow else {
            return
        }
        print(keyWindow)
    }
}
