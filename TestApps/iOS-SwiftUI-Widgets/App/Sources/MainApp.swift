import Combine
import SentrySampleShared
import SentrySwift
import SwiftUI
import UIKit
import UserNotifications

@main
struct MainApp: App {
    init() {
        // For this sample app we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true
            SentrySDKWrapper.shared.configureDataCollection(options)

            #if !SDK_V10
            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
            #endif // !SDK_V10
        }
    }

    var body: some Scene {
        WindowGroup {
            LiveActivityView()
        }
    }
}
