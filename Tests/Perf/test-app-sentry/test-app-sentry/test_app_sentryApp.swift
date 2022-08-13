import Sentry
import Sentry
import SwiftUI

@main
struct test_app_sentryApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
