// swiftlint:disable missing_docs
internal import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

@_spi(Private) @objc public final class SentryAppStateManager: NSObject {

    typealias Dependencies = CrashWrapperProvider
        & FileManagerProvider
        & SysctlProvider
        & DispatchQueueWrapperProvider
        & NotificationCenterProvider

    private let releaseName: String?
    private let crashWrapper: SentryCrashReporter
    private let fileManager: SentryFileManager?
    private let sysctlWrapper: SentrySysctl
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private let _updateAppState: (@escaping (SentryAppState) -> Void) -> Void
    private let _buildCurrentAppState: () -> SentryAppState

    private(set) var startCount = 0
#endif

    init(releaseName: String?, dependencies: Dependencies) {
        self.releaseName = releaseName
        crashWrapper = dependencies.crashWrapper
        fileManager = dependencies.fileManager
        sysctlWrapper = dependencies.sysctlWrapper
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        dispatchQueue = dependencies.dispatchQueueWrapper
        notificationCenter = dependencies.notificationCenterWrapper
        let lock = NSRecursiveLock()
        let buildCurrentAppState = { [crashWrapper, releaseName, sysctlWrapper] in
            // Is the current process being traced or not? If it is a debugger is attached.
            let isDebugging = crashWrapper.isBeingTraced

            let device = UIDevice.current
            let vendorId = device.identifierForVendor?.uuidString

            return SentryAppState(releaseName: releaseName, osVersion: device.systemVersion, vendorId: vendorId, isDebugging: isDebugging, systemBootTimestamp: sysctlWrapper.systemBootTimestamp)
        }
        _buildCurrentAppState = buildCurrentAppState
        let updateAppState: (@escaping (SentryAppState) -> Void) -> Void = { [fileManager] block in
            lock.synchronized {
                let appState = fileManager?.readAppState()
                if let appState {
                    block(appState)
                    fileManager?.store(appState)
                }
            }
        }
        _updateAppState = updateAppState
#endif
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

#if SENTRY_TEST || SENTRY_TEST_CI
    /// Test-only initializer to allow injecting a custom `buildCurrentAppState` closure for testing
    /// scenarios where the current app state needs specific values (e.g., nil vendorId).
    init(releaseName: String?, customBuildCurrentAppState: @escaping () -> SentryAppState, dependencies: Dependencies) {
        self.releaseName = releaseName
        crashWrapper = dependencies.crashWrapper
        fileManager = dependencies.fileManager
        sysctlWrapper = dependencies.sysctlWrapper
        dispatchQueue = dependencies.dispatchQueueWrapper
        notificationCenter = dependencies.notificationCenterWrapper
        let lock = NSRecursiveLock()
        _buildCurrentAppState = customBuildCurrentAppState
        let updateAppState: (@escaping (SentryAppState) -> Void) -> Void = { [fileManager] block in
            lock.synchronized {
                let appState = fileManager?.readAppState()
                if let appState {
                    block(appState)
                    fileManager?.store(appState)
                }
            }
        }
        _updateAppState = updateAppState
    }
#endif

    deinit {
        // In dealloc it's safe to unsubscribe for all, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        notificationCenter.removeObserver(self, name: nil, object: nil)
    }

    @objc public func start() {
        if startCount == 0 {
            notificationCenter.addObserver(
                self,
                selector: #selector(didBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(didBecomeActive),
                name: Notification.Name("SentryHybridSdkDidBecomeActive"),
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(willResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(willTerminate),
                name: UIApplication.willTerminateNotification,
                object: nil
            )

            storeCurrentAppState()
        }

        startCount += 1
    }

    @objc public func stop() {
        stop(withForce: false)
    }

    @objc public func stop(withForce forceStop: Bool) {
        guard startCount > 0 else {
            return
        }

        if forceStop {
            dispatchQueue.dispatchAsync { [self] in
                _updateAppState { $0.isSDKRunning = false }
            }
            startCount = 0
        } else {
            startCount -= 1
        }

        if startCount == 0 {
            // Remove the observers with the most specific detail possible, see
            // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
            notificationCenter.removeObserver(
                self,
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            notificationCenter.removeObserver(
                self,
                name: Notification.Name("SentryHybridSdkDidBecomeActive"),
                object: nil
            )
            notificationCenter.removeObserver(
                self,
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
            notificationCenter.removeObserver(
                self,
                name: UIApplication.willTerminateNotification,
                object: nil
            )
        }
    }

    /**
     * Builds the current app state.
     * @discussion The systemBootTimestamp is calculated by taking the current time and subtracting
     * @c NSProcessInfo.systemUptime . @c NSProcessInfo.systemUptime returns the amount of time the system
     * has been awake since the last time it was restarted. This means this is a good enough
     * approximation about the timestamp the system booted.
     */
    @objc public func buildCurrentAppState() -> SentryAppState {
        _buildCurrentAppState()
    }

    @objc public func loadPreviousAppState() -> SentryAppState? {
        fileManager?.readPreviousAppState()
    }

    func storeCurrentAppState() {
        fileManager?.store(buildCurrentAppState())
    }

    @objc public func updateAppState(_ block: @escaping (SentryAppState) -> Void) {
        _updateAppState(block)
    }

    /// It is called when an app is receiving events / it is in the foreground and when we receive a
    /// @c SentryHybridSdkDidBecomeActiveNotification.
    /// @discussion This also works when using SwiftUI or Scenes, as UIKit posts a
    /// @c didBecomeActiveNotification regardless of whether your app uses scenes, see
    /// https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622956-applicationdidbecomeactive.
    @objc private func didBecomeActive() {
        dispatchQueue.dispatchAsync { [self] in
            _updateAppState { $0.isActive = true }
        }
    }

    /// The app is about to lose focus / going to the background. This is only called when an app was
    /// receiving events / was is in the foreground.
    @objc private func willResignActive() {
        dispatchQueue.dispatchAsync { [self] in
            _updateAppState { $0.isActive = false }
        }
    }

    @objc private func willTerminate() {
        // The app is terminating so it is fine to do this on the main thread.
        // Furthermore, so users can manually post UIApplicationWillTerminateNotification and then call
        // exit(0), to avoid getting false watchdog terminations when using exit(0), see GH-1252.
        _updateAppState { $0.wasTerminated = true }
    }
#endif
}
// swiftlint:enable missing_docs
