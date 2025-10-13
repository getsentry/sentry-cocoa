@_implementationOnly import _SentryPrivate

@objc(SentryDependencies) @_spi(Private) public final class Dependencies: NSObject {
    @objc public static let processInfoWrapper: SentryProcessInfoSource = ProcessInfo.processInfo
    @objc public static let dispatchQueueWrapper = SentryDispatchQueueWrapper()
    @objc public static let dateProvider = SentryDefaultCurrentDateProvider()
    public static let objcRuntimeWrapper = SentryDefaultObjCRuntimeWrapper()
#if !os(watchOS) && !os(macOS) && !SENTRY_NO_UIKIT
    @objc public static let uiDeviceWrapper = SentryDefaultUIDeviceWrapper(queueWrapper: Dependencies.dispatchQueueWrapper)
#endif // !os(watchOS) && !os(macOS) && !SENTRY_NO_UIKIT

    @objc public static var threadInspector: SentryThreadInspector = SentryThreadInspector()

}
