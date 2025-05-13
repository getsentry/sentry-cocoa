import Foundation
import Sentry
import SentrySampleShared
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
