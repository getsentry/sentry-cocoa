import SentrySampleShared
import SentrySwift
import SwiftUI

@main
struct MacOSSwiftUIApp: App {
    init() {
        SentrySDKWrapper.shared.startSentry()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
