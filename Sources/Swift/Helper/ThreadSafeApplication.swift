// swiftlint:disable missing_docs
import Foundation
#if !os(macOS) && !os(watchOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

@_spi(Private) @objc public protocol SentryApplicationStateProvider: NSObjectProtocol {
    @objc var isApplicationInForeground: Bool { get }
}

final class SentryAlwaysForegroundApplicationStateProvider: NSObject, SentryApplicationStateProvider {
    // Non-UIKit apps do not enter UIKit's suspended background state. This matches the legacy
    // crash-state monitor, which treated these platforms as foreground for app-hang detection.
    var isApplicationInForeground: Bool { true }
}

#if !os(macOS) && !os(watchOS) && !SENTRY_NO_UI_FRAMEWORK
@objc @_spi(Private) public final class SentryThreadsafeApplication: NSObject, SentryApplicationStateProvider {
    private let notificationCenter: SentryNSNotificationCenterWrapper
    
    init(applicationProvider: @escaping () -> SentryApplication?, notificationCenter: SentryNSNotificationCenterWrapper, dispatchQueueWrapper: SentryDispatchQueueWrapper) {
        self.notificationCenter = notificationCenter
        // This matches the ObjC behavior which did not initialize the state when the UIApplication was null
        // so it kept a default value of 0 which happens to be defined to be `active`.
        // Acquiring the lock is not necessary here since the instance has not been initialized yet.
        let isMainThread = Thread.isMainThread
        if isMainThread, let application = applicationProvider() {
            self.state = SentryMutex(application.unsafeApplicationState)
        } else {
            if isMainThread {
                SentrySDKLog.warning("Application is null in SentryThreadsafeApplication")
            }
            self.state = SentryMutex(.active)
        }
        super.init()

        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        if !isMainThread {
            // UIKit only allows reading the application state on the main thread, and the dependency container
            // creates this instance eagerly on whichever thread first accesses it, for example a React Native
            // synchronous module method running on the JS thread. Blocking that thread until the main thread is
            // free is not acceptable during launch, so start from `.active` and refresh the state asynchronously
            // on the main queue, like the original ObjC implementation did. UIKit delivers the lifecycle
            // notifications on the main thread as well, so the refreshed value is never staler than a
            // notification that already arrived.
            SentrySDKLog.debug("SentryThreadsafeApplication initialized off the main thread, reading the application state asynchronously on the main queue.")
            dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self, let application = applicationProvider() else {
                    return
                }
                self.state.withLock { $0 = application.unsafeApplicationState }
            }
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self, name: nil, object: nil)
    }
    
    private let state: SentryMutex<UIApplication.State>
    @objc public var applicationState: UIApplication.State {
        state.withLock { $0 }
    }

    @objc public var isApplicationInForeground: Bool {
        applicationState != .background
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
    private func willEnterForeground() {
        state.withLock { $0 = .inactive }
    }

    @objc
    private func didBecomeActive() {
        state.withLock { $0 = .active }
    }
}
#endif
// swiftlint:enable missing_docs
