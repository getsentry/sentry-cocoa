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
        
        SentrySDK.configureScope { scope in
            if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                scope.add(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
            }
            
            if let data = "hello".data(using: .utf8) {
                scope.add(Attachment(data: data, filename: "log.txt"))
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
