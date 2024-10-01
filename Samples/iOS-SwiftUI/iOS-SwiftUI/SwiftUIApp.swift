import Foundation
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
            options.experimental.sessionReplay.sessionSampleRate = 1.0
            options.experimental.sessionReplay.maskAllImages = true
            options.experimental.sessionReplay.maskAllText = true
            options.initialScope = { scope in
                scope.injectGitInformation()
                return scope
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
