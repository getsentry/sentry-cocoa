// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

@objc(SentryDependencies) @_spi(Private) public final class Dependencies: NSObject {
    @objc public static let random: SentryRandomProtocol = SentryRandom()
    @objc public static let threadWrapper = SentryThreadWrapper()
    @objc public static let processInfoWrapper: SentryProcessInfoSource = ProcessInfo.processInfo
    static let infoPlistWrapper: SentryInfoPlistWrapperProvider = SentryInfoPlistWrapper()
    @objc public static let sessionReplayEnvironmentChecker: SentrySessionReplayEnvironmentChecker = {
        SentrySessionReplayEnvironmentChecker(infoPlistWrapper: Dependencies.infoPlistWrapper)
    }()
    @objc public static let dispatchQueueWrapper = SentryDispatchQueueWrapper()
    @objc public static let notificationCenterWrapper: SentryNSNotificationCenterWrapper = NotificationCenter.default
    @objc public static let crashWrapper: SentryCrashWrapper = {
        // Create a bridge for crashWrapper to use
        let container = SentryDependencyContainer.sharedInstance()
        let bridge = SentryCrashBridge(
            notificationCenterWrapper: container.notificationCenterWrapper,
            dateProvider: container.dateProvider,
            crashReporter: container.crashReporter
        )
        return SentryCrashWrapper(processInfoWrapper: Dependencies.processInfoWrapper, bridge: bridge)
    }()
    @objc public static let binaryImageCache = SentryBinaryImageCache()
    @objc public static let debugImageProvider = SentryDebugImageProvider()
    @objc public static let sysctlWrapper = SentrySysctl()
    @objc public static let dateProvider = SentryDefaultCurrentDateProvider()
    public static let objcRuntimeWrapper = SentryDefaultObjCRuntimeWrapper()
#if !os(watchOS) && !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    @objc public static let uiDeviceWrapper = SentryDefaultUIDeviceWrapper(queueWrapper: Dependencies.dispatchQueueWrapper)
#endif // !os(watchOS) && !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    @objc public static var threadInspector = SentryThreadInspector()
    @objc public static var fileIOTracker = SentryFileIOTracker(threadInspector: threadInspector, processInfoWrapper: processInfoWrapper)
}
// swiftlint:enable missing_docs
