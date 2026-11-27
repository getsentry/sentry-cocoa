import Cocoa
import SentrySampleShared
#if !SDK_V10
import SentrySwift
#else
import Sentry
#endif

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SentrySDKWrapper.shared.startSentry()
    }
}
