import Cocoa
import SentrySampleShared
import SentrySwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SentrySDKWrapper.shared.startSentry()
    }
}
