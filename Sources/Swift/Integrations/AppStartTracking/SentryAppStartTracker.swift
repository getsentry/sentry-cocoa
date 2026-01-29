@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit

/// Tracks cold and warm app start time for iOS, tvOS, and Mac Catalyst. The logic for the different
/// app start types is based on https://developer.apple.com/videos/play/wwdc2019/423/. Cold start:
/// After reboot of the device, the app is not in memory and no process exists. Warm start: When the
/// app recently terminated, the app is partially in memory and no process exists.
@_spi(Private) @objc
public final class SentryAppStartTracker: NSObject, SentryFramesTrackerListener {

    // MARK: - Static Properties

    /// The watchdog usually kicks in after an app hanging for 30 seconds. As the app could hang in
    /// multiple stages during the launch we pick a higher threshold.
    private static let maxAppStartDuration: TimeInterval = 180.0

    /// Invoked whenever this class is added to the Objective-C runtime.
    /// Set when the class is first loaded via SentryAppStartTrackerHelper.
    @objc public static var runtimeInitTimestamp = Date()

    /// The OS sets this environment variable if the app start is pre warmed. There are no official
    /// docs for this. Found at https://eisel.me/startup. Investigations show that this variable is
    /// deleted after UIApplicationDidFinishLaunchingNotification, so we have to check it here.
    /// Set via SentryAppStartTrackerHelper.
    @objc public static var isActivePrewarm = false

    // MARK: - Instance Properties
    // swiftlint:disable:next missing_docs
    @objc public private(set) var isRunning = false

    let dispatchQueue: SentryDispatchQueueWrapper
    let appStateManager: SentryAppStateManager
    private let framesTracker: SentryFramesTracker
    private let enablePreWarmedAppStartTracing: Bool

    private var previousAppState: SentryAppState?
    private var wasInBackground = false
    private var didFinishLaunchingTimestamp: Date

    #if !(SENTRY_TEST || SENTRY_TEST_CI || DEBUG)
    private var onceToken: Int = 0
    #endif

    // MARK: - Initialization

    init(
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        appStateManager: SentryAppStateManager,
        framesTracker: SentryFramesTracker,
        enablePreWarmedAppStartTracing: Bool
    ) {
        self.dispatchQueue = dispatchQueueWrapper
        self.appStateManager = appStateManager
        self.framesTracker = framesTracker
        self.enablePreWarmedAppStartTracing = enablePreWarmedAppStartTracing
        self.previousAppState = appStateManager.loadPreviousAppState()
        self.didFinishLaunchingTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()

        super.init()

        framesTracker.addListener(self)
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods
    func start() {
        // It can happen that the OS posts the didFinishLaunching notification before we register for it
        // or we just don't receive it. In this case the didFinishLaunchingTimestamp would be nil. As
        // the SDK should be initialized in application:didFinishLaunchingWithOptions: or in the init of
        // @main of a SwiftUI  we set the timestamp here.
        didFinishLaunchingTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didFinishLaunching),
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        if PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode {
            buildAppStartMeasurement(SentryDependencyContainer.sharedInstance().dateProvider.date())
        }

        appStateManager.start()

        isRunning = true
    }

    func stop() {
        // Remove the observers with the most specific detail possible, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        framesTracker.removeListener(self)

        #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
        isRunning = false
        #endif
    }

    // MARK: - SentryFramesTrackerListener

    /// This is when the first frame is drawn.
    @objc
    public func framesTrackerHasNewFrame(_ newFrameDate: Date) {
        buildAppStartMeasurement(newFrameDate)
    }

    // MARK: - Private Methods
    // swiftlint:disable function_body_length
    private func buildAppStartMeasurement(_ appStartEnd: Date) {
        let block = {
            self.stop()

            var isPreWarmed = false
            if self.isActivePrewarmAvailable() && Self.isActivePrewarm {
                SentrySDKLog.info("The app was prewarmed.")

                if self.enablePreWarmedAppStartTracing {
                    isPreWarmed = true
                } else {
                    SentrySDKLog.info("EnablePreWarmedAppStartTracing disabled. Not measuring app start.")
                    return
                }
            }

            let appStartType = self.getStartType()

            if appStartType == .unknown {
                SentrySDKLog.warning("Unknown start type. Not measuring app start.")
                return
            }

            if self.wasInBackground {
                // If the app was already running in the background it's not a cold or warm
                // start.
                SentrySDKLog.info("App was in background. Not measuring app start.")
                return
            }

            // According to a talk at WWDC about optimizing app launch
            // (https://devstreaming-cdn.apple.com/videos/wwdc/2019/423lzf3qsjedrzivc7/423/423_optimizing_app_launch.pdf?dl=1
            // slide 17) no process exists for cold and warm launches. Since iOS 15, though, the system
            // might decide to pre-warm your app before the user tries to open it.
            // Prewarming can stop at any of the app launch steps. Our findings show that most of
            // the prewarmed app starts don't call the main method. Therefore we subtract the
            // time before the module initialization / main method to calculate the app start
            // duration. If the app start stopped during a later launch step, we drop it below with
            // checking the SENTRY_APP_START_MAX_DURATION. With this approach, we will
            // lose some warm app starts, but we accept this tradeoff. Useful resources:
            // https://developer.apple.com/documentation/uikit/app_and_environment/responding_to_the_launch_of_your_app/about_the_app_launch_sequence#3894431
            // https://developer.apple.com/documentation/metrickit/mxapplaunchmetric,
            // https://twitter.com/steipete/status/1466013492180312068,
            // https://github.com/MobileNativeFoundation/discussions/discussions/146
            // https://eisel.me/startup
            let sysctl = SentryDependencyContainer.sharedInstance().sysctlWrapper
            let appStartTimestamp: Date
            let appStartDuration: TimeInterval

            if isPreWarmed {
                appStartDuration = appStartEnd.timeIntervalSince(sysctl.moduleInitializationTimestamp)
                appStartTimestamp = sysctl.moduleInitializationTimestamp
            } else {
                appStartDuration = appStartEnd.timeIntervalSince(sysctl.processStartTimestamp)
                appStartTimestamp = sysctl.processStartTimestamp
            }

            // Safety check to not report app starts that are completely off.
            if appStartDuration >= Self.maxAppStartDuration {
                SentrySDKLog.info("The app start exceeded the max duration of \(Self.maxAppStartDuration) seconds. Not measuring app start.")
                return
            }

            var finalAppStartDuration = appStartDuration
            var finalDidFinishLaunchingTimestamp = self.didFinishLaunchingTimestamp

            // On HybridSDKs, we miss the didFinishLaunchNotification and the
            // didBecomeVisibleNotification. Therefore, we can't set the
            // didFinishLaunchingTimestamp, and we can't calculate the appStartDuration. Instead,
            // the SDK provides the information we know and leaves the rest to the HybridSDKs.
            if PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode {
                finalDidFinishLaunchingTimestamp = Date(timeIntervalSinceReferenceDate: 0)
                finalAppStartDuration = 0
            }

            guard let sdkStart = SentrySDKInternal.startTimestamp else {
                SentrySDKLog.debug("Skipping app start measurement: missing SDK start timestamp.")
                return
            }

            let appStartMeasurement = SentryAppStartMeasurement(
                type: appStartType,
                isPreWarmed: isPreWarmed,
                appStartTimestamp: appStartTimestamp,
                runtimeInitSystemTimestamp: sysctl.runtimeInitSystemTimestamp,
                duration: finalAppStartDuration,
                runtimeInitTimestamp: Self.runtimeInitTimestamp,
                moduleInitializationTimestamp: sysctl.moduleInitializationTimestamp,
                sdkStartTimestamp: sdkStart,
                didFinishLaunchingTimestamp: finalDidFinishLaunchingTimestamp
            )

            SentrySDKInternal.setAppStartMeasurement(appStartMeasurement)
        }

        // With only running this once we know that the process is a new one when the following
        // code is executed.
        // We need to make sure the block runs on each test instead of only once
        #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
        block()
        #else
        dispatchQueue.dispatchOnce(&onceToken, block: block)
        #endif
    }
    // swiftlint:enable function_body_length

    private func getStartType() -> SentryAppStartType {
        // App launched the first time
        guard let previousAppState = previousAppState else {
            return .cold
        }

        let currentAppState = appStateManager.buildCurrentAppState()

        // If the release name is different we assume it's an app upgrade
        if currentAppState.releaseName != previousAppState.releaseName {
            return .cold
        }

        let intervalSincePreviousBootTime = previousAppState.systemBootTimestamp
            .timeIntervalSince(currentAppState.systemBootTimestamp)

        // System rebooted, because the previous boot time is in the past.
        if intervalSincePreviousBootTime < 0 {
            return .cold
        }

        // System didn't reboot, previous and current boot time are the same.
        if intervalSincePreviousBootTime == 0 {
            return .warm
        }

        // This should never be reached as we unsubscribe to didBecomeActive after it is called the
        // first time. If the previous boot time is in the future most likely the system time
        // changed and we can't to anything.
        return .unknown
    }

    private func isActivePrewarmAvailable() -> Bool {
        #if os(iOS)
        // Customer data suggest that app starts are also prewarmed on iOS 14 although this contradicts
        // with Apple docs.
        return true
        #else
        return false
        #endif
    }

    @objc
    private func didFinishLaunching() {
        didFinishLaunchingTimestamp = SentryDependencyContainer.sharedInstance().dateProvider.date()
    }

    @objc
    private func didEnterBackground() {
        wasInBackground = true
    }

    // MARK: - Test Helpers

    #if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
    /// Reloads static properties from the environment. Needed for testing.
    @objc
    public static func reloadEnvironment() {
        isActivePrewarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
        runtimeInitTimestamp = Date()
    }

    /// Sets the runtime init timestamp. Needed for testing, not public.
    @objc
    public func setRuntimeInit(_ value: Date) {
        Self.runtimeInitTimestamp = value
    }
    #endif
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
