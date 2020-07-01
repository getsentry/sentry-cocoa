import Foundation

class TestNotificationCenter {
    
    static func willEnterForeground() {
        NotificationCenter.default.post(Notification(name: UIApplication.willEnterForegroundNotification))
    }
    
    static func didBecomeActive() {
        NotificationCenter.default.post(Notification(name: UIApplication.didBecomeActiveNotification))
    }
    
    static func willResignActive() {
        NotificationCenter.default.post(Notification(name: UIApplication.willResignActiveNotification))
    }
    static func didEnterBackground() {
        NotificationCenter.default.post(Notification(name: UIApplication.didEnterBackgroundNotification))
    }
    
    static func willTerminate() {
        NotificationCenter.default.post(Notification(name: UIApplication.willTerminateNotification))
    }
}
