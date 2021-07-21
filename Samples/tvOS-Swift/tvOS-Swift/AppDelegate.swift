import Sentry
import SwiftUI
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.sessionTrackingIntervalMillis = 5_000
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
        }
        
        SentrySDK.configureScope { scope in
            if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                scope.add(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
            }
            
            if let data = "hello".data(using: .utf8) {
                scope.add(Attachment(data: data, filename: "log.txt"))
            }
        }

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
