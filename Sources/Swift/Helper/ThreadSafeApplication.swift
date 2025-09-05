#if !os(macOS) && !os(watchOS) && !SENTRY_NO_UIKIT
import UIKit

@objc @_spi(Private) public final class SentryThreadsafeApplication: NSObject {
    private let notificationCenter: SentryNSNotificationCenterWrapper
    
    @objc public init(initialState: UIApplication.State, notificationCenter: SentryNSNotificationCenterWrapper) {
        self.notificationCenter = notificationCenter
        _internalState = initialState
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
