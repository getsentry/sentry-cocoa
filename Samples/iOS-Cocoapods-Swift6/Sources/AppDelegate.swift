import Sentry
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.beforeSend = { event in
                print("Sentry: beforeSend called")
                return event
            }
            options.beforeSendSpan = { span in
                print("Sentry: beforeSendSpan called")
                return span
            }
            options.beforeCaptureScreenshot = { _ in
                print("Sentry: beforeCaptureScreenshot called")
                return true
            }
            options.beforeCaptureViewHierarchy = { _ in
                print("Sentry: beforeCaptureViewHierarchy called")
                return true
            }
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.debug = true
            options.sampleRate = 1
            options.tracesSampleRate = 1
        }

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

}
