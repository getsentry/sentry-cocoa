import SentrySwift
import SwiftUI

@main
struct SPMTestApp: App {
  init() {
    let options = Options()
    #if !SDK_V10
    options.enableAppHangTracking = true
    #endif // !SDK_V10
    options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
    options.sessionReplay.maskAllImages = false
    options.enableDataSwizzling = true
    options.enableFileManagerSwizzling = true
    SentrySDK.start(options: options)
    let user = User()
    SentrySDK.setUser(user)
    let breadcrumb = Breadcrumb(level: .error, category: "test")
    SentrySDK.addBreadcrumb(breadcrumb)
  }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
