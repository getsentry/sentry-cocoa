import Cocoa
import Sentry
import SentrySampleShared_Swift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SentrySDKWrapper.shared.startSentry()
    }
}
