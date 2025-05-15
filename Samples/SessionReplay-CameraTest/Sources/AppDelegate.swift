import Sentry
import SentrySampleShared
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var isSentryEnabled = true
    static var isSessionReplayEnabled = true
    static var isViewRendererV2Enabled = true

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.reloadSentrySDK()

        return true
    }

    static func reloadSentrySDK() {
        if SentrySDK.isEnabled {
            print("SentrySDK already started, closing it")
            SentrySDK.close()
        }

        if !isSentryEnabled {
            print("SentrySDK disabled")
            return
        }

        SentrySDKWrapper.shared.startSentry()
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
