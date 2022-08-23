import Foundation

#if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

class TestNotificationCenter {

    #if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
    static let willEnterForegroundNotification = UIApplication.willEnterForegroundNotification
    static let didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
    static let willResignActiveNotification = UIApplication.willResignActiveNotification
    static let didEnterBackgroundNotification = UIApplication.didEnterBackgroundNotification
    static let willTerminateNotification = UIApplication.willTerminateNotification
    static let didFinishLaunchingNotification = UIApplication.didFinishLaunchingNotification
    #elseif os(macOS)
    static let didBecomeActiveNotification = NSApplication.didBecomeActiveNotification
    static let willResignActiveNotification = NSApplication.willResignActiveNotification
    static let willTerminateNotification = NSApplication.willTerminateNotification
    static let didFinishLaunchingNotification = NSApplication.didFinishLaunchingNotification
    #endif
    
#if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
    static func willEnterForeground() {
        NotificationCenter.default.post(Notification(name: willEnterForegroundNotification))
    }

    static func didEnterBackground() {
        NotificationCenter.default.post(Notification(name: didEnterBackgroundNotification))
    }
    
    static func uiWindowDidBecomeVisible() {
        NotificationCenter.default.post(Notification(name: UIWindow.didBecomeVisibleNotification))
    }
#endif

    static func hybridSdkDidBecomeActive() {
        NotificationCenter.default.post(name: Notification.Name("SentryHybridSdkDidBecomeActive"), object: nil)
    }
    
    static func localeDidChange() {
        NotificationCenter.default.post(Notification(name: NSLocale.currentLocaleDidChangeNotification))
    }

    static func didBecomeActive() {
        NotificationCenter.default.post(Notification(name: didBecomeActiveNotification))
    }

    static func willResignActive() {
        NotificationCenter.default.post(Notification(name: willResignActiveNotification))
    }

    static func willTerminate() {
        NotificationCenter.default.post(Notification(name: willTerminateNotification))
    }

    static func didFinishLaunching() {
        NotificationCenter.default.post(Notification(name: didFinishLaunchingNotification))
    }
}
