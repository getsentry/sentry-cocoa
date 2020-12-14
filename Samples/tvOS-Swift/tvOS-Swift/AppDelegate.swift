import Sentry
import SwiftUI
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        SentrySDK.start { options in
            options.dsn = "https://387714a4f3654858a6f0ff63fd551485@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.logLevel = SentryLogLevel.verbose
            options.attachStacktrace = true
            options.sessionTrackingIntervalMillis = 5_000
        }
        
        SentrySDK.configureScope { scope in
            let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg")!
            scope.add(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
            
            scope.add(Attachment(data: "hello".data(using: .utf8)!, filename: "log.txt"))
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
