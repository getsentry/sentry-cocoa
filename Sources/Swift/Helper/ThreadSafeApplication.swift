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
            if Thread.isMainThread {
                _internalState = application.unsafeApplicationState
            } else {
                // UIApplication.applicationState must be accessed from the main thread,
                // so calling SentrySDK.start from a background thread or a non-main actor
                // would otherwise emit a `-[UIApplication applicationState] must be used
                // from main thread only` runtime warning (#6591). Hop to main to read
                // the value safely. The 10ms timeout matches the pattern used elsewhere
                // (e.g. internal_getWindows) — if main is contended we fall
                // back to the same default the null-application branch uses, and the
                // notification observers below will correct the state on the next
                // foreground/background transition.
                var stateOnMain: UIApplication.State = .active
                Dependencies.dispatchQueueWrapper.dispatchSyncOnMainQueue({
                    stateOnMain = application.unsafeApplicationState
                }, timeout: 0.01)
                _internalState = stateOnMain
            }
        } else {
            SentrySDKLog.warning("Application is null in SentryThreadsafeApplication")
            _internalState = .active
        }
        super.init()

        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self, name: nil, object: nil)
    }
    
    private let lock = NSRecursiveLock()
    private var _internalState: UIApplication.State
    @objc public var applicationState: UIApplication.State {
        var state: UIApplication.State
        lock.lock()
        state = _internalState
        lock.unlock()
        return state
    }

    @objc
    public var isActive: Bool {
        return applicationState == .active
    }

    @objc
    private func didEnterBackground() {
        lock.lock()
        _internalState = .background
        lock.unlock()
    }
    
    @objc
    private func didBecomeActive() {
        lock.lock()
        _internalState = .active
        lock.unlock()
    }
}
#endif
// swiftlint:enable missing_docs
