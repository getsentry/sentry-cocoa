import Sentry
import SwiftUI

@main
struct SwiftUICrashTestApp: App {

    init() {
        SentrySDK.start { options in
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
        }

        let userDefaultsKey = "crash-on-launch"
        if UserDefaults.standard.bool(forKey: userDefaultsKey) {

            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            SentrySDK.crash()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
