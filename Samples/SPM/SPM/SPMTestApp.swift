import SentrySwift
import SwiftUI

@main
struct SPMTestApp: App {
  init() {
    let options = Options()
    options.enableAppHangTracking = true
    options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
    options.sessionReplay.maskAllImages = false
    SentrySDK.start(options: options)
    let user = User()
    SentrySDK.setUser(user)
  }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
