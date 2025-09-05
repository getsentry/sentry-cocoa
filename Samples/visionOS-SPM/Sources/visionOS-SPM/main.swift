import Foundation
import Sentry
import SwiftUI

struct VisionOSApp: App {

    init() {
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
