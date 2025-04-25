import Sentry
import SwiftUI

@main
struct SwiftUIApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.tracesSampleRate = 1.0
            options.profilesSampleRate = 1.0

            options.sessionReplay.enableViewRendererV2 = true
            // Disable the fast view renderering, because we noticed parts (like the tab bar) are not rendered correctly
            options.sessionReplay.enableFastViewRendering = false

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
