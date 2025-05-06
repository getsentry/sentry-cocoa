import Cocoa
import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.tracesSampleRate = 1.0
            
            let args = ProcessInfo.processInfo.arguments

            // Set the profilesSampleRate to `nil` to enable the configureProfiling block
            options.profilesSampleRate = nil
            options.configureProfiling = {
                $0.profileAppStarts = ProcessInfo.processInfo.arguments.contains("--io.sentry.enable-profile-app-starts")
                $0.sessionSampleRate = 1
            }

            if args.contains("--disable-auto-performance-tracing") {
                options.enableAutoPerformanceTracing = false
            }

            if #available(macOS 12.0, *), !args.contains("--disable-metrickit-integration") {
                options.enableMetricKit = true
                options.enableMetricKitRawPayload = true
            }

            options.initialScope = { scope in
                if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                    scope.addAttachment(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
                }
                
                let data = Data("hello".utf8)
                scope.addAttachment(Attachment(data: data, filename: "log.txt"))
                
                injectGitInformation(scope: scope)
                
                return scope
            }

            options.experimental.enableFileManagerSwizzling = !args.contains("--disable-filemanager-swizzling")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}
