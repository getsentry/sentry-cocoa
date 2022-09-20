import Foundation
import XCTest

#if os(tvOS) || os(iOS)
import UIKit
#endif

class NotificationCenterTestCase: XCTestCase {

    #if os(tvOS) || os(iOS) 
    let willEnterForegroundNotification = UIApplication.willEnterForegroundNotification
    let didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
    let willResignActiveNotification = UIApplication.willResignActiveNotification
    let didEnterBackgroundNotification = UIApplication.didEnterBackgroundNotification
    let willTerminateNotification = UIApplication.willTerminateNotification
    let didFinishLaunchingNotification = UIApplication.didFinishLaunchingNotification
    #elseif os(macOS)
    static let didBecomeActiveNotification = NSApplication.didBecomeActiveNotification
    static let willResignActiveNotification = NSApplication.willResignActiveNotification
    static let willTerminateNotification = NSApplication.willTerminateNotification
    static let didFinishLaunchingNotification = NSApplication.didFinishLaunchingNotification
    #endif
    
    func goToForeground() {
        willEnterForeground()
        uiWindowDidBecomeVisible()
        didBecomeActive()
    }
    
    func goToBackground() {
        willResignActive()
        didEnterBackground()
    }
    
    func terminateApp() {
        willTerminate()
    }
    
    func willEnterForeground() {
        #if os(tvOS) || os(iOS)
        post(name: willEnterForegroundNotification)
        #endif
    }
    
    func didBecomeActive() {
        #if os(tvOS) || os(iOS)
        post(name: didBecomeActiveNotification)
        #endif
    }
    
    func willResignActive() {
        #if os(tvOS) || os(iOS)
        post(name: willResignActiveNotification)
        #endif
    }

    func didEnterBackground() {
        #if os(tvOS) || os(iOS)
        post(name: didEnterBackgroundNotification)
        #endif
    }

    func willTerminate() {
        #if os(tvOS) || os(iOS)
        post(name: willTerminateNotification)
        #endif
    }
    
    func hybridSdkDidBecomeActive() {
        post(name: Notification.Name("SentryHybridSdkDidBecomeActive"))
    }
    
    func didFinishLaunching() {
        #if os(tvOS) || os(iOS)
        post(name: didFinishLaunchingNotification)
        #endif
    }
    
    func uiWindowDidBecomeVisible() {
        #if os(tvOS) || os(iOS) || targetEnvironment(macCatalyst)
        post(name: UIWindow.didBecomeVisibleNotification)
        #endif
    }
    
    func localeDidChange() {
        post(name: NSLocale.currentLocaleDidChangeNotification)
    }
    
    private func post(name: Notification.Name) {
        NotificationCenter.default.post(Notification(name: name))
    }
}
