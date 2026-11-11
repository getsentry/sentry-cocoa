import SentrySampleShared
#if !SDK_V10
import SentrySwift
#else
import Sentry
#endif
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
