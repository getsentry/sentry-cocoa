import Sentry
import SentrySampleShared
import SwiftUI

@main
struct VisionOSSwiftApp: App {
    init() {
        SentrySDKWrapper.shared.startSentry()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
