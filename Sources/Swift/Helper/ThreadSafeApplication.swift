// swiftlint:disable missing_docs
#if !os(macOS) && !os(watchOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@objc @_spi(Private) public final class SentryThreadsafeApplication: NSObject {
    private let notificationCenter: SentryNSNotificationCenterWrapper
    
    init(applicationProvider: () -> SentryApplication?, notificationCenter: SentryNSNotificationCenterWrapper) {
        self.notificationCenter = notificationCenter
        // This matches the ObjC behavior which did not initialize the state when the UIApplication was null
        // so it kept a default value of 0 which happens to be defined to be `active`.
        // Acquiring the lock is not necessary here since the instance has not been initialized yet.
        if let application = applicationProvider() {
            self.state = SentryMutex(application.unsafeApplicationState)
        } else {
            SentrySDKLog.warning("Application is null in SentryThreadsafeApplication")
            self.state = SentryMutex(.active)
        }
        super.init()

        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self, name: nil, object: nil)
    }
    
    private let state: SentryMutex<UIApplication.State>
    @objc public var applicationState: UIApplication.State {
        state.withLock { $0 }
    }

    @objc
    public var isActive: Bool {
        return applicationState == .active
    }

    @objc
    private func didEnterBackground() {
        state.withLock { $0 = .background }
    }

    @objc
    private func didBecomeActive() {
        state.withLock { $0 = .active }
    }
}
#endif
// swiftlint:enable missing_docs
