import Cocoa
import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        SentrySDK.start { options in
            options.dsn = "https://387714a4f3654858a6f0ff63fd551485@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.logLevel = SentryLogLevel.verbose
            options.attachStacktrace = true
            options.sessionTrackingIntervalMillis = 5_000
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
