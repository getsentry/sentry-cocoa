import Sentry
import SwiftUI
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        SentrySDK.start(options: [
                   "dsn": "https://8ee5199a90354faf995292b15c196d48@o19635.ingest.sentry.io/4394",
                   "debug": true,
                   "logLevel": "verbose",
                   "enableAutoSessionTracking": true,
                   "sessionTrackingIntervalMillis": 5_000 
               ])

        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Use a UIHostingController as window root view controller.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}
