//swiftlint:disable file_length missing_docs

@_implementationOnly import _SentryPrivate
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

// Declare the application provider block at the top level to prevent capturing 'self'
// from the dependency container, which would create cyclic dependencies and memory leaks.
let defaultApplicationProvider: () -> SentryApplication? = {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    return UIApplication.shared
#elseif os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    return NSApplication.shared
#else
    return nil
#endif
}

// MARK: - Extensions

extension SentryFileManager: SentryFileManagerProtocol { }
@_spi(Private) extension SentryANRTrackerV1: SentryANRTrackerInternalProtocol { }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) extension SentryANRTrackerV2: SentryANRTrackerInternalProtocol { }

@_spi(Private) extension SentryDelayedFramesTracker: SentryDelayedFramesTrackerWrapper {
    func getFramesDelay(_ startSystemTimestamp: UInt64, endSystemTimestamp: UInt64, isRunning: Bool, slowFrameThreshold: CFTimeInterval) -> SentryFramesDelayResult {
        let objcResult = getFramesDelayObjC(startSystemTimestamp, endSystemTimestamp: endSystemTimestamp, isRunning: isRunning, slowFrameThreshold: slowFrameThreshold)
        return .init(delayDuration: objcResult.delayDuration, framesContributingToDelayCount: objcResult.framesContributingToDelayCount)
    }
}
#endif

// MARK: - SentryDependencyContainer
// swiftlint:disable type_body_length
@_spi(Private) @objc public final class SentryDependencyContainer: NSObject {

    // MARK: Private

    private static let instanceLock = NSRecursiveLock()
    private static var instance = SentryDependencyContainer()
    private let paramLock = NSRecursiveLock()

    private func getLazyVar<T>(_ keyPath: ReferenceWritableKeyPath<SentryDependencyContainer, T?>, builder: () -> T) -> T {
        paramLock.synchronized {
            guard let result = self[keyPath: keyPath] else {
                let result = builder()
                self[keyPath: keyPath] = result
                return result
            }
            return result
        }
    }

    private func getOptionalLazyVar<T>(_ keyPath: ReferenceWritableKeyPath<SentryDependencyContainer, T?>, builder: () -> T?) -> T? {
        paramLock.synchronized {
            guard let result = self[keyPath: keyPath] else {
                let result = builder()
                self[keyPath: keyPath] = result
                return result
            }
            return result
        }
    }

    // MARK: Public

    private var _startOptions: Options?
    @objc public var startOptions: Options? {
        get { paramLock.synchronized { _startOptions } }
        set { paramLock.synchronized { _startOptions = newValue } }
    }

    @objc public static func sharedInstance() -> SentryDependencyContainer {
        instanceLock.synchronized {
            return instance
        }
    }

    /**
     * Resets all dependencies.
     */
    @objc public static func reset() {
        instanceLock.synchronized {
            // Access _startOptions directly instead of through the paramLock-protected getter
            // to avoid a deadlock: instanceLock → paramLock here vs paramLock → instanceLock
            // in lazy var builders that transitively call sharedInstance(). This is safe because
            // instanceLock blocks the only external write path (SentrySDK.setStart → sharedInstance).
            let currentOptions = instance._startOptions
            instance.reachability.removeAllObservers()
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            instance._framesTracker?.stop()
#endif
            instance = SentryDependencyContainer()
            instance._startOptions = currentOptions
        }
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    var applicationOverride: SentryApplication?
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    var windowFactoryOverride: SentryUserFeedbackWindowFactory?
#endif
#endif
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    var sessionReplayCaptureScheduler: SentrySessionReplayRunLoopCaptureScheduler = DefaultSentrySessionReplayRunLoopCaptureScheduler()
#endif
    @objc public func application() -> SentryApplication? {
#if SENTRY_TEST || SENTRY_TEST_CI
    let `override` = self.applicationOverride
    if let `override` {
        return `override`
    }
#endif
        return defaultApplicationProvider()
    }

    private lazy var sessionDispatchQueue = SentryDispatchQueueWrapper(name: "io.sentry.session-tracker")

    func getSessionTracker(with options: Options) -> SessionTracker {
        return SessionTracker(options: options, applicationProvider: defaultApplicationProvider, dateProvider: dateProvider, notificationCenter: notificationCenterWrapper, dispatchQueue: sessionDispatchQueue)
    }

    @objc public var dispatchQueueWrapper = Dependencies.dispatchQueueWrapper
    @objc public var random = Dependencies.random
    @objc public var threadWrapper = Dependencies.threadWrapper
    @objc public var binaryImageCache = Dependencies.binaryImageCache
    @objc public var dateProvider: SentryCurrentDateProvider = Dependencies.dateProvider
    @objc public var notificationCenterWrapper = Dependencies.notificationCenterWrapper
    @objc public var processInfoWrapper = Dependencies.processInfoWrapper
    private var _crashWrapper: SentryCrashReporter?
    @objc public lazy var crashWrapper: SentryCrashReporter = getLazyVar(\._crashWrapper) {
        let bridge = SentryCrashBridge(
            notificationCenterWrapper: self.notificationCenterWrapper,
            dateProvider: self.dateProvider,
            crashReporter: self.crashReporter
        )
        return SentryDefaultCrashReporter(processInfoWrapper: Dependencies.processInfoWrapper, bridge: bridge)
    }
    @objc public var dispatchFactory = SentryDispatchFactory()
    @objc public var timerFactory = SentryNSTimerFactory()
    private var _fileIOTracker: SentryFileIOTracker?
    @objc public lazy var fileIOTracker: SentryFileIOTracker = getLazyVar(\._fileIOTracker) {
        SentryFileIOTracker(threadInspector: self.threadInspector, processInfoWrapper: Dependencies.processInfoWrapper)
    }
    private var _threadInspector: SentryThreadInspector?
    @objc public lazy var threadInspector: SentryThreadInspector = getLazyVar(\._threadInspector) {
        SentryThreadInspector(options: self.startOptions)
    }
    var nsDataSwizzling = SentryNSDataSwizzling()
    var nsFileManagerSwizzling = SentryNSFileManagerSwizzling()
    @objc public var rateLimits: RateLimits = DefaultRateLimits(
        retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: Dependencies.dateProvider),
        andRateLimitParser: RateLimitParser(currentDateProvider: Dependencies.dateProvider),
        currentDateProvider: Dependencies.dateProvider)
    @objc public var reachability = SentryReachability()
    @objc public var sysctlWrapper = Dependencies.sysctlWrapper
    @objc public var debugImageProvider = Dependencies.debugImageProvider
    @objc public var objcRuntimeWrapper: SentryObjCRuntimeWrapper = SentryDefaultObjCRuntimeWrapper()
    var extensionDetector: SentryExtensionDetector = {
        SentryExtensionDetector(infoPlistWrapper: Dependencies.infoPlistWrapper)
    }()
    var coreDataSwizzling = SentryCoreDataSwizzling()
    // This is a var so that it's initialized lazily on first access. It never should get set
    // to a different value.
    lazy var hangTracker: HangTracker = DefaultHangTracker(dateProvider: Dependencies.dateProvider)

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    private var _extraContextProvider: SentryExtraContextProvider?
    @objc public lazy var extraContextProvider: SentryExtraContextProvider = getLazyVar(\._extraContextProvider) {
        SentryExtraContextProvider(crashWrapper: self.crashWrapper, processInfoWrapper: Dependencies.processInfoWrapper, deviceWrapper: Dependencies.uiDeviceWrapper)
    }
#else
    private var _extraContextProvider: SentryExtraContextProvider?
    @objc public lazy var extraContextProvider: SentryExtraContextProvider = getLazyVar(\._extraContextProvider) {
        SentryExtraContextProvider(crashWrapper: self.crashWrapper, processInfoWrapper: Dependencies.processInfoWrapper)
    }
#endif

    private var _eventContextEnricher: SentryEventContextEnricher?
    @objc public var eventContextEnricher: SentryEventContextEnricher {
        getLazyVar(\._eventContextEnricher) {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            SentryDefaultEventContextEnricher(applicationStateProvider: { [weak self] in
                self?.threadsafeApplication.applicationState
            })
#else
            SentryDefaultEventContextEnricher()
#endif
        }
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    @objc public var uiDeviceWrapper: SentryUIDeviceWrapper = Dependencies.uiDeviceWrapper
    @objc public var threadsafeApplication = SentryThreadsafeApplication(applicationProvider: defaultApplicationProvider, notificationCenter: Dependencies.notificationCenterWrapper)
    @objc public var swizzleWrapper = SentrySwizzleWrapper()

    // MARK: Lazy Vars

    private var _watchdogTerminationAttributesProcessor: SentryWatchdogTerminationAttributesProcessor?
    @objc public lazy var watchdogTerminationAttributesProcessor =
        getLazyVar(\._watchdogTerminationAttributesProcessor) {
            SentryWatchdogTerminationAttributesProcessor(
                withDispatchQueueWrapper: dispatchFactory.createUtilityQueue("io.sentry.watchdog-termination-tracking.fields-processor", relativePriority: 0),
                scopePersistentStore: scopePersistentStore)
        }

    private var _uiViewControllerPerformanceTracker: SentryUIViewControllerPerformanceTracker?
    @objc public lazy var uiViewControllerPerformanceTracker = getLazyVar(\._uiViewControllerPerformanceTracker) {
        SentryUIViewControllerPerformanceTracker()
    }

    private var _framesTracker: SentryFramesTracker?
    @objc public lazy var framesTracker = getLazyVar(\._framesTracker) {
        let sentryAutoTransactionMaxDuration = 500.0
        let delayedFramesTracker = SentryDelayedFramesTracker(keepDelayedFramesDuration: sentryAutoTransactionMaxDuration)
        return SentryFramesTracker(displayLinkWrapper: SentryDisplayLinkWrapper(), dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueueWrapper, notificationCenter: notificationCenterWrapper, delayedFramesTracker: delayedFramesTracker)
    }

    private var _viewHierarchyProvider: SentryViewHierarchyProvider?
    @objc public lazy var viewHierarchyProvider: SentryViewHierarchyProvider? = getOptionalLazyVar(\._viewHierarchyProvider) {
        SentryViewHierarchyProvider(dispatchQueueWrapper: dispatchQueueWrapper, applicationProvider: defaultApplicationProvider)
    }

    @objc public func getWatchdogTerminationScopeObserverWithOptions(_ options: Options) -> SentryScopeObserver {
         return SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: Int(options.maxBreadcrumbs)),
            attributesProcessor: watchdogTerminationAttributesProcessor)
    }

    private var terminationTracker: SentryWatchdogTerminationTracker?
    func getWatchdogTerminationTracker(_ options: Options) -> SentryWatchdogTerminationTracker? {
        getOptionalLazyVar(\.terminationTracker) {

            guard let fileManager = fileManager else {
                SentrySDKLog.fatal("File manager is not available")
                return nil
            }

            guard let scopeStore = scopePersistentStore else {
                SentrySDKLog.fatal("Scope persistent store is not available")
                return nil
            }

            let dispatchQueueWrapper = dispatchFactory.createUtilityQueue("io.sentry.watchdog-termination-tracker", relativePriority: 0)

            let logic = SentryWatchdogTerminationLogic(options: options,
                                                       crashAdapter: crashWrapper,
                                                       appStateManager: appStateManager)
            return SentryWatchdogTerminationTracker(
                options: options,
                watchdogTerminationLogic: logic,
                appStateManager: appStateManager,
                dispatchQueueWrapper: dispatchQueueWrapper,
                fileManager: fileManager,
                scopePersistentStore: scopeStore)
        }
    }

    func getUIViewControllerSwizzlingBuilder(_ options: Options) -> SentryUIViewControllerSwizzling {

        let dispatchQueue = dispatchFactory.createHighPriorityQueue("io.sentry.ui-view-controller-swizzling")

        let subClassFinder = SentrySubClassFinder(
            dispatchQueue: dispatchQueue,
            objcRuntimeWrapper: objcRuntimeWrapper,
            swizzleClassNameExcludes: options.swizzleClassNameExcludes
        )

        let swizzling = SentryUIViewControllerSwizzling(
            options: options,
            dispatchQueue: dispatchQueue,
            objcRuntimeWrapper: objcRuntimeWrapper,
            subClassFinder: subClassFinder,
            processInfoWrapper: processInfoWrapper,
            performanceTracker: uiViewControllerPerformanceTracker
        )

        return swizzling
    }

    func getUIEventTracker(_ options: Options) -> SentryUIEventTracker {
        let mode = SentryUIEventTrackerTransactionMode(idleTimeout: options.idleTimeout)
        return SentryUIEventTracker(
            mode: mode,
            reportAccessibilityIdentifier: options.reportAccessibilityIdentifier
        )
    }

    func getAppStartTracker(_ options: Options) -> SentryAppStartTracker {
        return SentryAppStartTracker(
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            appStateManager: appStateManager,
            framesTracker: framesTracker,
            enablePreWarmedAppStartTracing: options.enablePreWarmedAppStartTracing,
            enableStandaloneAppStartTracing: options.experimental.enableStandaloneAppStartTracing,
            dateProvider: dateProvider,
            sysctlWrapper: sysctlWrapper,
            appStartInfoProvider: appStartInfoProvider,
            extendedAppLaunchManager: extendedAppLaunchManager
        )
    }

    private var _appStartInfoProvider: AppStartInfoProvider?
    lazy var appStartInfoProvider: AppStartInfoProvider = getLazyVar(\._appStartInfoProvider) {
        SentryAppStartTrackerHelper()
    }

    private var _extendedAppLaunchManager: SentryExtendedAppLaunchManager?
    var extendedAppLaunchManager: SentryExtendedAppLaunchManager {
        get { getLazyVar(\._extendedAppLaunchManager) { SentryExtendedAppLaunchManager() } }
        set { _extendedAppLaunchManager = newValue }
    }
#endif

    private var crashIntegrationSessionHandler: SentryCrashIntegrationSessionHandler?
    func getCrashIntegrationSessionBuilder(_ options: Options, bridge: SentryCrashBridge) -> SentryCrashIntegrationSessionHandler? {
        getOptionalLazyVar(\.crashIntegrationSessionHandler) {

            guard let fileManager = fileManager else {
                SentrySDKLog.fatal("File manager is not available")
                return nil
            }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            let watchdogLogic = SentryWatchdogTerminationLogic(options: options,
                                                       crashAdapter: crashWrapper,
                                                       appStateManager: appStateManager)
            return SentryCrashIntegrationSessionHandler(
                crashWrapper: crashWrapper,
                watchdogTerminationLogic: watchdogLogic,
                fileManager: fileManager,
                bridge: bridge
            )
#else
            return SentryCrashIntegrationSessionHandler(crashWrapper: crashWrapper, fileManager: fileManager, bridge: bridge)
#endif
        }
    }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    private var _screenshotSource: SentryScreenshotSource?
    @objc public lazy var screenshotSource: SentryScreenshotSource? = getOptionalLazyVar(\._screenshotSource) {
        // The options could be null here, but this is a general issue in the dependency
        // container and will be fixed in a future refactoring.
        guard let options = self.startOptions else {
            return nil
        }

        let viewRenderer: SentryViewRenderer
        if options.screenshot.enableViewRendererV2 {
            viewRenderer = SentryViewRendererV2(enableFastViewRendering: options.screenshot.enableFastViewRendering)
        } else {
            viewRenderer = SentryDefaultViewRenderer()
        }

        let photographer = SentryViewPhotographer(
            renderer: viewRenderer,
            redactOptions: options.screenshot,
            enableMaskRendererV2: options.screenshot.enableViewRendererV2)
        return SentryScreenshotSource(photographer: photographer)
    }

    private var _sessionReplayBreadcrumbConverter: SentryReplayBreadcrumbConverter?
    var sessionReplayBreadcrumbConverter: SentryReplayBreadcrumbConverter {
        get { getLazyVar(\._sessionReplayBreadcrumbConverter) { SentrySRDefaultBreadcrumbConverter() } }
        set { _sessionReplayBreadcrumbConverter = newValue }
    }
#endif

    private var _fileManager: SentryFileManager?
    @objc public lazy var fileManager: SentryFileManager? = getOptionalLazyVar(\._fileManager) {
        do {
            return try SentryFileManager(dateProvider: Dependencies.dateProvider, dispatchQueueWrapper: Dependencies.dispatchQueueWrapper)
        } catch {
            SentrySDKLog.debug("Could not create file manager - \(error)")
            return nil
        }
    }
    private var _scopePersistentStore: SentryScopePersistentStore?
    @objc public lazy var scopePersistentStore = getOptionalLazyVar(\._scopePersistentStore) {
        SentryScopePersistentStore(fileManager: fileManager)
    }
    private var _globalEventProcessor: SentryGlobalEventProcessor?
    @objc public lazy var globalEventProcessor = getLazyVar(\._globalEventProcessor) {
        SentryGlobalEventProcessor()
    }
    private var _appStateManager: SentryAppStateManager?
    @objc public lazy var appStateManager = getLazyVar(\._appStateManager) {
        let release = self.startOptions?.releaseName
        return SentryAppStateManager(
            releaseName: release,
            crashWrapper: crashWrapper,
            fileManager: fileManager,
            sysctlWrapper: sysctlWrapper)
    }
    private var _crashReporter: SentryCrashSwift?
    @objc public lazy var crashReporter = getLazyVar(\._crashReporter) {
        SentryCrashSwift(with: self.startOptions?.cacheDirectoryPath)
    }

    private var anrTracker: SentryANRTracker?
    @objc public func getANRTracker(_ timeout: TimeInterval) -> SentryANRTracker {
        getLazyVar(\.anrTracker) {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
            SentryANRTracker(helper: SentryANRTrackerV2(timeoutInterval: timeout))
        #else
            SentryANRTracker(helper: SentryANRTrackerV1(timeoutInterval: timeout))
        #endif
        }
    }

    private var crashInstallationReporter: SentryCrashInstallationReporter?
    func getCrashInstallationReporter(_ options: Options) -> SentryCrashInstallationReporter {
        getLazyVar(\.crashInstallationReporter) {
            let inAppLogic = SentryInAppLogic(inAppIncludes: options.inAppIncludes)

            return SentryCrashInstallationReporter(
                inAppLogic: inAppLogic,
                crashWrapper: crashWrapper,
                dispatchQueue: dispatchQueueWrapper
            )
        }
    }

    func getCoreDataTracker(_ options: Options) -> SentryCoreDataTracker {
        let threadInspector = SentryDefaultThreadInspector(options: options)
        return SentryCoreDataTracker(
            threadInspector: threadInspector,
            processInfoWrapper: processInfoWrapper
        )
    }
}
// swiftlint:enable type_body_length

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
extension SentryDependencyContainer: ScreenshotSourceProvider { }
extension SentryDependencyContainer: WindowFactoryProvider {
    var windowFactory: SentryUserFeedbackWindowFactory {
#if SENTRY_TEST || SENTRY_TEST_CI
        if let override = windowFactoryOverride {
            return override
        }
#endif
        return SentryUserFeedbackWidget.defaultWindowFactory
    }
}
#endif

protocol ClientProvider {
    var client: SentryClientInternal? { get }
}

extension SentryDependencyContainer: ClientProvider {
    var client: SentryClientInternal? {
        // Eventually we will want to have the current shared hub to live in the dependency container aswell
        // Until then, we proxy the static accessor.
        SentrySDKInternal.currentHub().getClient()
    }
}

protocol Hub {
    func configureScope(_ callback: @escaping (Scope) -> Void)
    func storeEnvelope(_ envelope: SentryEnvelope)
    func captureEnvelope(_ envelope: SentryEnvelope)
    func setTrace(_ traceId: SentryId, spanId: SpanId)
    var options: Options { get }
}

protocol HubProvider {
    var hub: Hub { get }
}

/// DefaultHub is a temporary abstraction around the ``SentryHubInternal.h``
private struct DefaultHub: Hub {
    func configureScope(_ callback: @escaping (Scope) -> Void) {
        SentrySDKInternal.currentHub().configureScope { scope in
            callback(scope)
        }
    }

    func storeEnvelope(_ envelope: SentryEnvelope) {
        SentrySDKInternal.currentHub().store(envelope)
    }

    func captureEnvelope(_ envelope: SentryEnvelope) {
        SentrySDKInternal.currentHub().capture(envelope)
    }

    func setTrace(_ traceId: SentryId, spanId: SpanId) {
        SentrySDKInternal.currentHub().configureScope { scope in
            scope.setPropagationContext(traceId: traceId, spanId: spanId)
        }
    }

    var options: Options {
        SentrySDKInternal.currentHub().getClient()?.getOptions() as? Options ?? Options()
    }
}

extension SentryDependencyContainer: HubProvider {
    var hub: Hub { DefaultHub() }
}

protocol DateProviderProvider {
    var dateProvider: SentryCurrentDateProvider { get }
}
extension SentryDependencyContainer: DateProviderProvider {}

extension SentryDependencyContainer: AutoSessionTrackingProvider { }

protocol FileIOTrackerProvider {
    var fileIOTracker: SentryFileIOTracker { get }
}

protocol NSDataSwizzlingProvider {
    var nsDataSwizzling: SentryNSDataSwizzling { get }
}

protocol NSFileManagerSwizzlingProvider {
    var nsFileManagerSwizzling: SentryNSFileManagerSwizzling { get }
}

extension SentryDependencyContainer: FileIOTrackerProvider { }
extension SentryDependencyContainer: NSDataSwizzlingProvider { }
extension SentryDependencyContainer: NSFileManagerSwizzlingProvider { }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
protocol FramesTrackingProvider {
    var framesTracker: SentryFramesTracker { get }
}

extension SentryDependencyContainer: FramesTrackingProvider { }
#endif

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
protocol ScreenshotIntegrationProvider {
    var screenshotSource: SentryScreenshotSource? { get }
}

extension SentryDependencyContainer: ScreenshotIntegrationProvider { }

protocol ViewHierarchyProviderProvider {
    var viewHierarchyProvider: SentryViewHierarchyProvider? { get }
}

extension SentryDependencyContainer: ViewHierarchyProviderProvider { }

protocol SessionReplayCaptureSchedulerProvider {
    var sessionReplayCaptureScheduler: SentrySessionReplayRunLoopCaptureScheduler { get }
}

extension SentryDependencyContainer: SessionReplayCaptureSchedulerProvider { }

protocol SessionReplayBreadcrumbConverterProvider {
    var sessionReplayBreadcrumbConverter: SentryReplayBreadcrumbConverter { get }
}

extension SentryDependencyContainer: SessionReplayBreadcrumbConverterProvider { }

protocol ReplayIntegrationProvider {
    func getReplayIntegration() -> SentrySessionReplayIntegration?
}

private struct DefaultReplayIntegrationProvider: ReplayIntegrationProvider {
    func getReplayIntegration() -> SentrySessionReplayIntegration? {
        SentrySDKInternal.currentHub().getInstalledIntegration(
            SentrySessionReplayIntegration.self
        ) as? SentrySessionReplayIntegration
    }
}

protocol ReplayIntegrationProviderProvider {
    var replayIntegrationProvider: ReplayIntegrationProvider { get }
}

extension SentryDependencyContainer: ReplayIntegrationProviderProvider {
    var replayIntegrationProvider: ReplayIntegrationProvider { DefaultReplayIntegrationProvider() }
}
#endif

protocol ExtraContextProviderProvider {
    var extraContextProvider: SentryExtraContextProvider { get }
}
extension SentryDependencyContainer: ExtraContextProviderProvider { }

protocol SdkMetadataProvider {
    var sdkName: String { get nonmutating set }
    var sdkVersion: String { get nonmutating set }
}

struct DefaultSdkMetadataProvider: SdkMetadataProvider {
    var sdkName: String {
        get { SentryMeta.sdkName }
        nonmutating set { SentryMeta.sdkName = newValue }
    }
    var sdkVersion: String {
        get { SentryMeta.versionString }
        nonmutating set { SentryMeta.versionString = newValue }
    }
}

protocol SdkMetadataProviderProvider {
    var sdkMetadataProvider: SdkMetadataProvider { get }
}

extension SentryDependencyContainer: SdkMetadataProviderProvider {
    var sdkMetadataProvider: SdkMetadataProvider { DefaultSdkMetadataProvider() }
}

protocol SdkPackagesProvider {
    func addPackage(name: String, version: String)
}

struct DefaultSdkPackagesProvider: SdkPackagesProvider {
    func addPackage(name: String, version: String) {
        SentryExtraPackages.addPackageName(name, version: version)
    }
}

protocol SdkPackagesProviderProvider {
    var sdkPackagesProvider: SdkPackagesProvider { get }
}

extension SentryDependencyContainer: SdkPackagesProviderProvider {
    var sdkPackagesProvider: SdkPackagesProvider { DefaultSdkPackagesProvider() }
}

protocol InstallationIdProvider {
    var installationID: String { get }
}

struct DefaultInstallationIdProvider: InstallationIdProvider {
    var installationID: String {
        PrivateSentrySDKOnly.installationID
    }
}

protocol InstallationIdProviderProvider {
    var installationIdProvider: InstallationIdProvider { get }
}

extension SentryDependencyContainer: InstallationIdProviderProvider {
    var installationIdProvider: InstallationIdProvider { DefaultInstallationIdProvider() }
}

protocol NotificationCenterProvider {
    var notificationCenterWrapper: SentryNSNotificationCenterWrapper { get }
}
extension SentryDependencyContainer: NotificationCenterProvider {}

protocol RateLimitsProvider {
    var rateLimits: RateLimits { get }
}
extension SentryDependencyContainer: RateLimitsProvider {}

protocol CurrentDateProvider {
    var dateProvider: SentryCurrentDateProvider { get }
}
extension SentryDependencyContainer: CurrentDateProvider {}

protocol RandomProvider {
    var random: SentryRandomProtocol { get }
}
extension SentryDependencyContainer: RandomProvider {}

protocol FileManagerProvider {
    var fileManager: SentryFileManager? { get }
}
extension SentryDependencyContainer: FileManagerProvider {}

protocol ReachabilityProvider {
    var reachability: SentryReachability { get }
}
extension SentryDependencyContainer: ReachabilityProvider {}

protocol CrashWrapperProvider {
    var crashWrapper: SentryCrashReporter { get }
}
extension SentryDependencyContainer: CrashWrapperProvider {}

protocol GlobalEventProcessorProvider {
    var globalEventProcessor: SentryGlobalEventProcessor { get }
}
extension SentryDependencyContainer: GlobalEventProcessorProvider {}

protocol DispatchQueueWrapperProvider {
    var dispatchQueueWrapper: SentryDispatchQueueWrapper { get }
}
extension SentryDependencyContainer: DispatchQueueWrapperProvider {}
extension SentryDependencyContainer: SentryMetricsIntegrationDependencies {}

protocol ApplicationProvider {
    func application() -> SentryApplication?
}
extension SentryDependencyContainer: ApplicationProvider {}

protocol DispatchFactoryProvider {
    var dispatchFactory: SentryDispatchFactory { get }
}
extension SentryDependencyContainer: DispatchFactoryProvider {}

protocol ExtensionDetectorProvider {
    var extensionDetector: SentryExtensionDetector { get }
}
extension SentryDependencyContainer: ExtensionDetectorProvider { }

protocol DebugImageProvider {
    var debugImageProvider: SentryDebugImageProvider { get }
}
extension SentryDependencyContainer: DebugImageProvider { }

protocol BinaryImageCacheProvider {
    var binaryImageCache: SentryBinaryImageCache { get }
}
extension SentryDependencyContainer: BinaryImageCacheProvider { }

protocol BreadcrumbDeserializer {
    func breadcrumb(from dictionary: [String: Any]) -> Breadcrumb
}

struct DefaultBreadcrumbDeserializer: BreadcrumbDeserializer {
    func breadcrumb(from dictionary: [String: Any]) -> Breadcrumb {
        PrivateSentrySDKOnly.breadcrumb(with: dictionary)
    }
}

protocol BreadcrumbDeserializerProvider {
    var breadcrumbDeserializer: BreadcrumbDeserializer { get }
}

extension SentryDependencyContainer: BreadcrumbDeserializerProvider {
    var breadcrumbDeserializer: BreadcrumbDeserializer { DefaultBreadcrumbDeserializer() }
}

protocol UserDeserializer {
    func user(from dictionary: [String: Any]) -> User
}

struct DefaultUserDeserializer: UserDeserializer {
    func user(from dictionary: [String: Any]) -> User {
        PrivateSentrySDKOnly.user(with: dictionary)
    }
}

protocol UserDeserializerProvider {
    var userDeserializer: UserDeserializer { get }
}

extension SentryDependencyContainer: UserDeserializerProvider {
    var userDeserializer: UserDeserializer { DefaultUserDeserializer() }
}

protocol OptionsDeserializer {
    func options(from dictionary: [String: Any]) throws -> Options
}

struct DefaultOptionsDeserializer: OptionsDeserializer {
    func options(from dictionary: [String: Any]) throws -> Options {
        guard let options = try SentryOptionsHelper.makeOptions(fromDictionary: dictionary) as? Options else {
            throw NSError(domain: "SentryInternalApi", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create options from dictionary"
            ])
        }
        return options
    }
}

protocol OptionsDeserializerProvider {
    var optionsDeserializer: OptionsDeserializer { get }
}

extension SentryDependencyContainer: OptionsDeserializerProvider {
    var optionsDeserializer: OptionsDeserializer { DefaultOptionsDeserializer() }
}

protocol ThreadInspectorProvider {
    var threadInspector: SentryThreadInspector { get }
}
extension SentryDependencyContainer: ThreadInspectorProvider { }

protocol ANRTrackerBuilder {
    func getANRTracker(_ interval: TimeInterval) -> SentryANRTracker
}
extension SentryDependencyContainer: ANRTrackerBuilder { }

protocol ProcessInfoProvider {
    var processInfoWrapper: SentryProcessInfoSource { get }
}
extension SentryDependencyContainer: ProcessInfoProvider { }

protocol AppStateManagerProvider {
    var appStateManager: SentryAppStateManager { get }
}
extension SentryDependencyContainer: AppStateManagerProvider { }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
protocol WatchdogTerminationScopeObserverBuilder {
    func getWatchdogTerminationScopeObserverWithOptions(_ options: Options) -> SentryScopeObserver
}
extension SentryDependencyContainer: WatchdogTerminationScopeObserverBuilder { }

protocol WatchdogTerminationTrackerBuilder {
    func getWatchdogTerminationTracker(_ options: Options) -> SentryWatchdogTerminationTracker?
}
extension SentryDependencyContainer: WatchdogTerminationTrackerBuilder {}
#endif

protocol NetworkTrackerProvider {
    var networkTracker: SentryNetworkTracker { get }
}
extension SentryDependencyContainer: NetworkTrackerProvider {
    // Inject the network tracer via the Dependency Container
    // Because this is used in swizzling, we cannot remove the singleton
    // or that may lead to issues when stopping and enablign the SDK again
    var networkTracker: SentryNetworkTracker {
        SentryNetworkTracker.sharedInstance
    }
}

protocol SentryCrashReporterProvider {
    var crashReporter: SentryCrashSwift { get }
}
extension SentryDependencyContainer: SentryCrashReporterProvider {}

protocol CrashIntegrationSessionHandlerBuilder {
    func getCrashIntegrationSessionBuilder(_ options: Options, bridge: SentryCrashBridge) -> SentryCrashIntegrationSessionHandler?
}
extension SentryDependencyContainer: CrashIntegrationSessionHandlerBuilder {}

protocol CrashInstallationReporterBuilder {
    func getCrashInstallationReporter(_ options: Options) -> SentryCrashInstallationReporter
}
extension SentryDependencyContainer: CrashInstallationReporterBuilder {}

protocol SentryCoreDataSwizzlingProvider {
    var coreDataSwizzling: SentryCoreDataSwizzling { get }
}
extension SentryDependencyContainer: SentryCoreDataSwizzlingProvider {}

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
protocol SentryUIDeviceWrapperProvider {
    var uiDeviceWrapper: SentryUIDeviceWrapper { get }
}

extension SentryDependencyContainer: SentryUIDeviceWrapperProvider {}

protocol UIViewControllerPerformanceTrackerProvider {
    var uiViewControllerPerformanceTracker: SentryUIViewControllerPerformanceTracker { get }
}
extension SentryDependencyContainer: UIViewControllerPerformanceTrackerProvider {}

protocol UIViewControllerSwizzlingBuilder {
    func getUIViewControllerSwizzlingBuilder(_ options: Options) -> SentryUIViewControllerSwizzling
}
extension SentryDependencyContainer: UIViewControllerSwizzlingBuilder {}

protocol SentryEventTrackerBuilder {
    func getUIEventTracker(_ options: Options) -> SentryUIEventTracker
}
extension SentryDependencyContainer: SentryEventTrackerBuilder {}

protocol SentryAppStartTrackerBuilder {
    func getAppStartTracker(_ options: Options) -> SentryAppStartTracker
}
extension SentryDependencyContainer: SentryAppStartTrackerBuilder {}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

protocol SentryCoreDataTrackerBuilder {
    func getCoreDataTracker(_ options: Options) -> SentryCoreDataTracker
}
extension SentryDependencyContainer: SentryCoreDataTrackerBuilder {}

//swiftlint:enable file_length missing_docs
