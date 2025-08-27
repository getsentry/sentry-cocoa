import Sentry
import SwiftUI

@main
struct SwiftUICrashTestApp: App {

    init() {
        // Using `NSLog` so it shows up in the logs and `SwiftUICrashTestApp` to easily find it in the logs.
        NSLog("SwiftUICrashTestApp - app launched")
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
        }
        NSLog("SwiftUICrashTestApp - SDK Started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Moved the crash from init to onAppear to ensure the app is fully loaded before crashing.
                    // This prevents test flakiness on CI that occurred when the crash happened during the app launch.
                    let userDefaultsKey = "crash-on-launch"
                    if UserDefaults.standard.bool(forKey: userDefaultsKey) {
                        NSLog("SwiftUICrashTestApp - will crash")
                        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            SentrySDK.crash()
                        }
                    } else {
                        NSLog("SwiftUICrashTestApp - will not crash")
                    }
                }
        }
    }
}
