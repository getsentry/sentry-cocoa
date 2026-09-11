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
    private let applicationProvider: () -> SentryApplication?
    
    init(applicationProvider: @escaping () -> SentryApplication?, notificationCenter: SentryNSNotificationCenterWrapper) {
        self.notificationCenter = notificationCenter
        self.applicationProvider = applicationProvider
        // Acquiring the lock is not necessary here since the instance has not been initialized yet.
        let applicationIsAvailable: Bool
        if let application = applicationProvider() {
            self.state = SentryMutex(application.unsafeApplicationState)
            applicationIsAvailable = true
        } else {
            // The SDK can start before UIApplication exists, for example from a SwiftUI `App.init`,
            // which runs before `UIApplicationMain`. This matches the ObjC behavior which did not
            // initialize the state when the UIApplication was null so it kept a default value of 0
            // which happens to be defined to be `active`. That default is only correct for a
            // foreground launch: a process the system launches in the background, for example for
            // HealthKit background delivery or a background URLSession, never posts
            // `didBecomeActive` or `didEnterBackground`, so nothing would ever correct it and the
            // SDK would treat the whole background lifetime as foreground. The real state is read
            // once UIApplication is up, at `didFinishLaunchingNotification`.
            SentrySDKLog.warning("Application is null in SentryThreadsafeApplication. Assuming active until UIApplicationDidFinishLaunchingNotification.")
            self.state = SentryMutex(.active)
            applicationIsAvailable = false
        }
        super.init()

        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        if !applicationIsAvailable {
            notificationCenter.addObserver(self, selector: #selector(didFinishLaunching), name: UIApplication.didFinishLaunchingNotification, object: nil)
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

    /// Only observed when the application was not available at init. The notification is posted on
    /// the main thread, where reading `unsafeApplicationState` is safe, and it precedes every other
    /// lifecycle notification, so resolving here cannot overwrite a state a later notification set.
    @objc
    private func didFinishLaunching() {
        notificationCenter.removeObserver(self, name: UIApplication.didFinishLaunchingNotification, object: nil)
        guard let application = applicationProvider() else {
            SentrySDKLog.warning("Application is still null in SentryThreadsafeApplication after launch. Keeping the active default.")
            return
        }
        let launchState = application.unsafeApplicationState
        state.withLock { $0 = launchState }
    }
}
#endif
// swiftlint:enable missing_docs
