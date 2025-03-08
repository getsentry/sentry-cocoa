import Foundation
import XCTest

#if os(tvOS) || os(iOS)
import UIKit
#endif

class NotificationCenterTestCase: XCTestCase {

    #if os(tvOS) || os(iOS)
    private let willEnterForegroundNotification = UIApplication.willEnterForegroundNotification
    private let didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
    private let willResignActiveNotification = UIApplication.willResignActiveNotification
    private let didEnterBackgroundNotification = UIApplication.didEnterBackgroundNotification
    private let willTerminateNotification = UIApplication.willTerminateNotification
    private let didFinishLaunchingNotification = UIApplication.didFinishLaunchingNotification
    #elseif os(macOS)
    private let didBecomeActiveNotification = NSApplication.didBecomeActiveNotification
    private let willResignActiveNotification = NSApplication.willResignActiveNotification
    private let willTerminateNotification = NSApplication.willTerminateNotification
    private let didFinishLaunchingNotification = NSApplication.didFinishLaunchingNotification
    #endif

    // swiftlint:disable test_case_accessibility
    // This is a base test class, so it's methods can't be private

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
        #if os(tvOS) || os(iOS) || os(macOS)
        post(name: didBecomeActiveNotification)
        #endif
    }

    func willResignActive() {
        #if os(tvOS) || os(iOS) || os(macOS)
        post(name: willResignActiveNotification)
        #endif
    }

    func didEnterBackground() {
        #if os(tvOS) || os(iOS)
        post(name: didEnterBackgroundNotification)
        #endif
    }

    func willTerminate() {
        #if os(tvOS) || os(iOS) || os(macOS)
        post(name: willTerminateNotification)
        #endif
    }

    func hybridSdkDidBecomeActive() {
        post(name: Notification.Name("SentryHybridSdkDidBecomeActive"))
    }

    func didFinishLaunching() {
        #if os(tvOS) || os(iOS) || os(macOS)
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

    // swiftlint:enable test_case_accessibility

    private func post(name: Notification.Name) {
        NotificationCenter.default.post(Notification(name: name))
    }
}
