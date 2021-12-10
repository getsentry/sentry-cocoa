import Foundation

#if os(tvOS) || os(iOS)
import UIKit
#endif

class TestNotificationCenter {

    #if os(tvOS) || os(iOS) 
    private static let willEnterForegroundNotification = UIApplication.willEnterForegroundNotification
    private static let didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
    private static let willResignActiveNotification = UIApplication.willResignActiveNotification
    private static let didEnterBackgroundNotification = UIApplication.didEnterBackgroundNotification
    private static let willTerminateNotification = UIApplication.willTerminateNotification
    private static let didFinishLaunchingNotification = UIApplication.didFinishLaunchingNotification
    #elseif os(macOS)
    private static let didBecomeActiveNotification = NSApplication.didBecomeActiveNotification
    private static let willResignActiveNotification = NSApplication.willResignActiveNotification
    private static let willTerminateNotification = NSApplication.willTerminateNotification
    private static let didFinishLaunchingNotification = NSApplication.didFinishLaunchingNotification
    #endif
    
    static func willEnterForeground() {
        #if os(tvOS) || os(iOS)
        NotificationCenter.default.post(Notification(name: willEnterForegroundNotification))
        #endif
    }
    
    static func didBecomeActive() {
        #if os(tvOS) || os(iOS) || os(macOS)
        NotificationCenter.default.post(Notification(name: didBecomeActiveNotification))
        #endif
    }
    
    static func willResignActive() {
        #if os(tvOS) || os(iOS) || os(macOS)
        NotificationCenter.default.post(Notification(name: willResignActiveNotification))
        #endif
    }

    static func didEnterBackground() {
        #if os(tvOS) || os(iOS)
        NotificationCenter.default.post(Notification(name: didEnterBackgroundNotification))
        #endif
    }

    static func willTerminate() {
        #if os(tvOS) || os(iOS) || os(macOS)
        NotificationCenter.default.post(Notification(name: willTerminateNotification))
        #endif
    }
    
    static func hybridSdkDidBecomeActive() {
        NotificationCenter.default.post(name: Notification.Name("SentryHybridSdkDidBecomeActive"), object: nil)
    }
    
    static func didFinishLaunching() {
        #if os(tvOS) || os(iOS) || os(macOS)
        NotificationCenter.default.post(Notification(name: didFinishLaunchingNotification))
        #endif
    }
    
    static func uiWindowDidBecomeVisible() {
        #if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
        NotificationCenter.default.post(Notification(name: UIWindow.didBecomeVisibleNotification))
        #endif
    }
    
    static func localeDidChange() {
        NotificationCenter.default.post(Notification(name: NSLocale.currentLocaleDidChangeNotification))
    }
}
