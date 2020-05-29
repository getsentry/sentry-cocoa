import Cocoa
import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        SentrySDK.start(options: [
            "dsn": "https://8ee5199a90354faf995292b15c196d48@o19635.ingest.sentry.io/4394",
            "debug": true,
            "logLevel": "verbose",
            "enableAutoSessionTracking": true,
            "attachStacktrace": true,
            "sessionTrackingIntervalMillis": 5_000 // 5 seconds session timeout for testing
        ])
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
