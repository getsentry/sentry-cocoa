import Sentry
import SentrySampleShared_Swift
import SwiftUI

@main
struct MacOSSwiftUIApp: App {
    
    @NSApplicationDelegateAdaptor private var appDelegate: MyAppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class MyAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SentrySDKWrapper.shared.startSentry()
    }
}
