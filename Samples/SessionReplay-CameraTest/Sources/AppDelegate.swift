import Sentry
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var isSessionReplayEnabled = true
    static var isExperimentalViewRendererEnabled = true

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.reloadSentrySDK()

        return true
    }

    static func reloadSentrySDK() {
        if SentrySDK.isEnabled {
            print("SentrySDK already started, closing it")
            SentrySDK.close()
        }

        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true

            options.tracesSampleRate = 1.0
            options.profilesSampleRate = 1.0
            options.sessionReplay.sessionSampleRate = Self.isSessionReplayEnabled ? 1.0 : 0.0

            options.initialScope = { scope in
                scope.injectGitInformation()
                scope.setTag(value: "session-replay-camera-test", key: "sample-project")
                return scope
            }

            // Experimental features
            options.sessionReplay.enableExperimentalViewRenderer = Self.isExperimentalViewRendererEnabled
            // Disable the fast view renderering, because we noticed parts (like the tab bar) are not rendered correctly
            options.sessionReplay.enableFastViewRendering = false
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
