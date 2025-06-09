import Sentry
import SwiftUI

@main
struct MultiPlatformSampleApp: App {
    init() {
        SentrySDK.start { options in
            options.debug = true
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
} 
