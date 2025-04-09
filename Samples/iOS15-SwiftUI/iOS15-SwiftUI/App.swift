import Sentry
import SentrySampleShared_Swift
import SwiftUI

@main
struct SwiftUIApp: App {
    init() {
        SentrySDKWrapper.shared.startSentry()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
