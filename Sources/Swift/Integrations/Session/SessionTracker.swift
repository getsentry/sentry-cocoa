@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
import UIKit
typealias Application = UIApplication
#elseif (os(macOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
import AppKit
typealias Application = NSApplication
#endif

/// Tracks sessions for release health. For more info see:
/// https://docs.sentry.io/workflow/releases/health/#session
@_spi(Private) @objc(SentrySessionTracker) public final class SessionTracker: NSObject {
    
    // MARK: Private

    private var wasStartSessionCalled = false
    private let applicationProvider: () -> SentryApplication?
    private let lock = NSRecursiveLock()
    private var lastInForeground: Date?
    private var lastInForegroundLock = NSRecursiveLock()

    private static let SentryHybridSdkDidBecomeActiveNotificationName = NSNotification.Name("SentryHybridSdkDidBecomeActive")

    // MARK: Lifecycle

    @objc public init(options: Options, applicationProvider: @escaping () -> SentryApplication?, dateProvider: SentryCurrentDateProvider, notificationCenter: SentryNSNotificationCenterWrapper) {
        self.options = options
        self.applicationProvider = applicationProvider
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
    }
    
    deinit {
        removeObservers()

        // In dealloc it's safe to unsubscribe for all, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        self.notificationCenter.removeObserver(self, name: nil, object: nil)
    }

    // MARK: Public
    
    @objc public func start() {
        // We don't want to use WillEnterForeground because tvOS doesn't call it when it launches an app
        // the first time. It only calls it when the app was open and the user navigates back to it.
        // DidEnterBackground is called when the app launches a background task so we would need to
        // check if DidBecomeActive was called before to not track sessions in the background.
        // DidBecomeActive and WillResignActive are not called when the app launches a background task.
        // WillTerminate is called no matter if started from the background or launched into the
        // foreground.

    #if ((os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT) || ((os(macOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT)
        
        // Call before subscribing to the notifications to avoid that didBecomeActive gets called before
        // ending the cached session.
        endCachedSession()

        self.notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: Application.didBecomeActiveNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: Self.SentryHybridSdkDidBecomeActiveNotificationName, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(willResignActive), name: Application.willResignActiveNotification, object: nil)
        self.notificationCenter.addObserver(self, selector: #selector(willTerminate), name: Application.willTerminateNotification, object: nil)

        // Edge case: When starting the SDK after the app did become active, we need to call
        //            didBecomeActive manually to start the session. This is the case when
        //            closing the SDK and starting it again.
        if self.application?.mainThread_isActive ?? false {
            self.startSession()
        }
        
    #else
        SentrySDKLog.debug("NO UIKit -> SentrySessionTracker will not track sessions automatically.")
    #endif
    }
    
    @objc public func stop() {
        SentryDependencyContainerSwiftHelper.currentHub().endSession()

        removeObservers()

        // Reset the `wasStartSessionCalled` flag to ensure that the next time
        // `startSession` is called, it will start a new session.
        wasStartSessionCalled = false
    }
    
    @objc public func removeObservers() {
#if ((os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT) || ((os(macOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT)
        // Remove the observers with the most specific detail possible, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        notificationCenter.removeObserver(self, name: Application.didBecomeActiveNotification, object: nil)
        notificationCenter.removeObserver(self, name: Self.SentryHybridSdkDidBecomeActiveNotificationName, object: nil)
        notificationCenter.removeObserver(self, name: Application.willResignActiveNotification, object: nil)
        notificationCenter.removeObserver(self, name: Application.willTerminateNotification, object: nil)
#endif
    }
    
    // MARK: Internal
    
    let options: Options
    let dateProvider: SentryCurrentDateProvider
    let notificationCenter: SentryNSNotificationCenterWrapper
    
    var application: SentryApplication? {
        applicationProvider()
    }

    /// End previously cached sessions. We never can be sure that WillResignActive or WillTerminate are
    /// called due to a crash or unexpected behavior. Still, we don't want to lose such sessions and end
    /// them.
    func endCachedSession() {
        let lastInForeground = SentryDependencyContainerSwiftHelper.readTimestampLastInForeground()
        if lastInForeground != nil {
            SentryDependencyContainerSwiftHelper.deleteTimestampLastInForeground()
        }

        let hub = SentryDependencyContainerSwiftHelper.currentHub()
        hub.closeCachedSession(withTimestamp: lastInForeground)
    }

    /// It is called when an App. is receiving events / It is in the foreground and when we receive a
    /// @c SentryHybridSdkDidBecomeActiveNotification. There is no guarantee that this method is called
    /// once or twice. We need to ensure that we execute it only once.
    /// @discussion This also works when using SwiftUI or Scenes, as UIKit posts a
    /// @c didBecomeActiveNotification regardless of whether your app uses scenes, see
    /// https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622956-applicationdidbecomeactive.
    /// @warning Hybrid SDKs must only post this notification if they are running in the foreground
    /// because the auto session tracking logic doesn't support background tasks. Posting the
    /// notification from the background would mess up the session stats.
    @objc func didBecomeActive() {
        startSession()
    }

    func startSession() {
        // We don't know if the hybrid SDKs post the notification from a background thread, so we
        // synchronize to be safe.
        // NOTE: This is not actually safe, because the state is accessed from other methods without the lock.
        // It was preserved when migrating from ObjC but would be expected to cause a crash if this function was
        // called from a background thread.
        let shouldEarlyReturn = lock.synchronized {
            if wasStartSessionCalled {
                SentrySDKLog.debug("Ignoring didBecomeActive notification because it was already called.")
                return true
            }
            wasStartSessionCalled = true
            return false
        }
        if shouldEarlyReturn {
            return
        }

        let hub = SentryDependencyContainerSwiftHelper.currentHub()
        let lastInForeground = SentryDependencyContainerSwiftHelper.readTimestampLastInForeground()

        if let lastInForeground {
            // When the app was already in the foreground we have to decide whether it was long enough
            // in the background to start a new session or to keep the session open. We don't want a new
            // session if the user switches to another app for just a few seconds.
            let secondsInBackground = dateProvider.date().timeIntervalSince(lastInForeground)

            if secondsInBackground * 1_000 >= Double(options.sessionTrackingIntervalMillis) {
                SentrySDKLog.debug("App was in the background for \(secondsInBackground) seconds. Starting a new session.")
                hub.endSession(withTimestamp: lastInForeground)
                hub.startSession()
            } else {
                SentrySDKLog.debug("App was in the background for \(secondsInBackground) seconds. Not starting a new session.")
            }
        } else {
            // Cause we don't want to track sessions if the app is in the background we need to wait
            // until the app is in the foreground to start a session.
            SentrySDKLog.debug("App was in the foreground for the first time. Starting a new session.")
            hub.startSession()
        }
        SentryDependencyContainerSwiftHelper.deleteTimestampLastInForeground()
        lastInForegroundLock.synchronized {
            self.lastInForeground = nil
        }

    #if !(os(watchOS) || os(tvOS) || (swift(>=5.9) && os(visionOS)))
        if SentryDependencyContainerSwiftHelper.hasProfilingOptions() {
            sentry_reevaluateSessionSampleRate()
        }
    #endif // SENTRY_TARGET_PROFILING_SUPPORTED
    }

    /// The app is about to lose focus / going to the background. This is only called when an app was
    /// receiving events / was is in the foreground. We can't end a session here because we don't how
    /// long the app is going to be in the background. If it is just for a few seconds we want to keep
    /// the session open.
    @objc func willResignActive() {
        let lastInForeground = dateProvider.date()
        SentryDependencyContainerSwiftHelper.storeTimestampLast(inForeground: lastInForeground)
        wasStartSessionCalled = false
        lastInForegroundLock.synchronized {
            self.lastInForeground = lastInForeground
        }
    }

    /// We always end the session when the app is terminated.
    @objc func willTerminate() {
        let lastInForeground = lastInForegroundLock.synchronized { return self.lastInForeground }
        let sessionEnded = lastInForeground ?? dateProvider.date()
        SentryDependencyContainerSwiftHelper.currentHub().endSession(withTimestamp: sessionEnded)
        SentryDependencyContainerSwiftHelper.deleteTimestampLastInForeground()
        wasStartSessionCalled = false
    }
}
