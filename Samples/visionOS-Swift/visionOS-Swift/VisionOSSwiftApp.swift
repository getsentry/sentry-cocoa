import Sentry
import SwiftUI

@main
struct VisionOSSwiftApp: App {

    init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.tracesSampleRate = 1.0
            options.attachScreenshot = true
            options.attachViewHierarchy = true

            // Experimental features
            options.experimental.enableFileManagerSwizzling = true
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
