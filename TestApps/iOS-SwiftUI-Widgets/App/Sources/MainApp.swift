import Combine
import Sentry
import SentrySampleShared
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

        }
    }

    var body: some Scene {
        WindowGroup {
            LiveActivityView()
        }
    }
}
