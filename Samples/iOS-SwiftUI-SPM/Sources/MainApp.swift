import SentrySwift
import SwiftUI

@main
struct MainApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.tracesSampleRate = 1
            options.enableAutoPerformanceTracing = true
            options.enableUIViewControllerTracing = true
            options.enableUserInteractionTracing = true
            options.enableTimeToFullDisplayTracing = true
            options.attachScreenshot = true
            options.enableMetricKit = true
            options.enableLogs = true

            #if targetEnvironment(simulator)
            options.enableSpotlight = true
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
