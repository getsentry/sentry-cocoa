import Foundation
import Sentry
import SwiftUI

@main
struct SwiftUIApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.sessionTrackingIntervalMillis = 5_000
            // Sampling 100% - In Production you probably want to adjust this
            options.tracesSampleRate = 1.0
            options.enableFileIOTracing = true
            options.profilesSampleRate = 1.0
            options.enableUserInteractionTracing = true
        }
    }


    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
