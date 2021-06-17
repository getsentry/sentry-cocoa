import Sentry
import SwiftUI

@main
struct From_SourceApp: App {
    
    init() {
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.sessionTrackingIntervalMillis = 5_000
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
