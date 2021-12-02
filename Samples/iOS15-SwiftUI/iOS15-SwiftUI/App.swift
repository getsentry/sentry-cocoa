import Sentry
import SwiftUI

@main
struct SwiftUIApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.sessionTrackingIntervalMillis = 5_000
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
