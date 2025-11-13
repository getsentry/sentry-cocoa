@_implementationOnly import _SentryPrivate

@objc(SentryDependencies) @_spi(Private) public final class Dependencies: NSObject {
    @objc nonisolated(unsafe) public static let random: SentryRandomProtocol = SentryRandom()
    @objc nonisolated(unsafe) public static let threadWrapper = SentryThreadWrapper()
    @objc public static let processInfoWrapper: SentryProcessInfoSource & Sendable = ProcessInfo.processInfo
    static let infoPlistWrapper: SentryInfoPlistWrapperProvider = SentryInfoPlistWrapper()
    @objc public static let sessionReplayEnvironmentChecker: SentrySessionReplayEnvironmentChecker = {
        SentrySessionReplayEnvironmentChecker(infoPlistWrapper: Dependencies.infoPlistWrapper)
    }()
    @objc nonisolated(unsafe) public static let dispatchQueueWrapper = SentryDispatchQueueWrapper()
    @objc public static let notificationCenterWrapper: SentryNSNotificationCenterWrapper = NotificationCenter.default
    @objc nonisolated(unsafe) public static let crashWrapper = SentryCrashWrapper(processInfoWrapper: Dependencies.processInfoWrapper)
    @objc nonisolated(unsafe) public static let binaryImageCache = SentryBinaryImageCache()
    @objc nonisolated(unsafe) public static let debugImageProvider = SentryDebugImageProvider()
    @objc nonisolated(unsafe)  public static let sysctlWrapper = SentrySysctl()
    @objc public static let dateProvider = SentryDefaultCurrentDateProvider()
    public static let objcRuntimeWrapper = SentryDefaultObjCRuntimeWrapper()
#if !os(watchOS) && !os(macOS) && !SENTRY_NO_UIKIT
    @objc nonisolated(unsafe) public static let uiDeviceWrapper = SentryDefaultUIDeviceWrapper(queueWrapper: Dependencies.dispatchQueueWrapper)
#endif // !os(watchOS) && !os(macOS) && !SENTRY_NO_UIKIT
    @objc nonisolated(unsafe) public static var threadInspector = SentryThreadInspector()
    @objc nonisolated(unsafe) public static var fileIOTracker = SentryFileIOTracker(threadInspector: threadInspector, processInfoWrapper: processInfoWrapper)

}

#if compiler(<6.0)
extension ProcessInfo: @unchecked Sendable { }
#endif
