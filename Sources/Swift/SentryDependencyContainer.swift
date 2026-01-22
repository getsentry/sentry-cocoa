//swiftlint:disable file_length missing_docs

@_implementationOnly import _SentryPrivate
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

// Declare the application provider block at the top level to prevent capturing 'self'
// from the dependency container, which would create cyclic dependencies and memory leaks.
let defaultApplicationProvider: () -> SentryApplication? = {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    return UIApplication.shared
#elseif os(macOS)
    return NSApplication.shared
#else
    return nil
#endif
}

// MARK: - Extensions

extension SentryFileManager: SentryFileManagerProtocol { }
@_spi(Private) extension SentryANRTrackerV1: SentryANRTrackerInternalProtocol { }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
@_spi(Private) extension SentryANRTrackerV2: SentryANRTrackerInternalProtocol { }

@_spi(Private) extension SentryDelayedFramesTracker: SentryDelayedFramesTrackerWrapper {
    func getFramesDelay(_ startSystemTimestamp: UInt64, endSystemTimestamp: UInt64, isRunning: Bool, slowFrameThreshold: CFTimeInterval) -> SentryFramesDelayResult {
        let objcResult = getFramesDelayObjC(startSystemTimestamp, endSystemTimestamp: endSystemTimestamp, isRunning: isRunning, slowFrameThreshold: slowFrameThreshold)
        return .init(delayDuration: objcResult.delayDuration, framesContributingToDelayCount: objcResult.framesContributingToDelayCount)
    }
}
#endif

// MARK: - SentryDependencyContainer
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
            instance.reachability.removeAllObservers()
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
            instance._framesTracker?.stop()
#endif
            instance = SentryDependencyContainer()
        }
    }
    
#if SENTRY_TEST || SENTRY_TEST_CI
    var applicationOverride: SentryApplication?
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
    
    func getSessionTracker(with options: Options) -> SessionTracker {
        return SessionTracker(options: options, applicationProvider: defaultApplicationProvider, dateProvider: dateProvider, notificationCenter: notificationCenterWrapper)
    }
    
    @objc public var dispatchQueueWrapper = Dependencies.dispatchQueueWrapper
    @objc public var random = Dependencies.random
    @objc public var threadWrapper = Dependencies.threadWrapper
    @objc public var binaryImageCache = Dependencies.binaryImageCache
    @objc public var dateProvider: SentryCurrentDateProvider = Dependencies.dateProvider
    @objc public var notificationCenterWrapper = Dependencies.notificationCenterWrapper
    @objc public var processInfoWrapper = Dependencies.processInfoWrapper
    @objc public var crashWrapper = Dependencies.crashWrapper
    @objc public var dispatchFactory = SentryDispatchFactory()
    @objc public var timerFactory = SentryNSTimerFactory()
    @objc public var fileIOTracker = Dependencies.fileIOTracker
    @objc public var threadInspector = Dependencies.threadInspector
    @objc public var nsDataSwizzling = SentryNSDataSwizzling.shared
    @objc public var nsFileManagerSwizzling = SentryNSFileManagerSwizzling.shared
    @objc public var rateLimits: RateLimits = DefaultRateLimits(
        retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: Dependencies.dateProvider),
        andRateLimitParser: RateLimitParser(currentDateProvider: Dependencies.dateProvider),
        currentDateProvider: Dependencies.dateProvider)
    @objc public var reachability = SentryReachability()
    @objc public var sysctlWrapper = Dependencies.sysctlWrapper
    @objc public var sessionReplayEnvironmentChecker: SentrySessionReplayEnvironmentCheckerProvider = Dependencies.sessionReplayEnvironmentChecker
    @objc public var debugImageProvider = Dependencies.debugImageProvider
    @objc public var objcRuntimeWrapper: SentryObjCRuntimeWrapper = SentryDefaultObjCRuntimeWrapper()
    var extensionDetector: SentryExtensionDetector = {
        SentryExtensionDetector(infoPlistWrapper: Dependencies.infoPlistWrapper)
    }()
    
#if os(iOS) && !SENTRY_NO_UIKIT
    @objc public var extraContextProvider = SentryExtraContextProvider(crashWrapper: Dependencies.crashWrapper, processInfoWrapper: Dependencies.processInfoWrapper, deviceWrapper: Dependencies.uiDeviceWrapper)
#else
    @objc public var extraContextProvider = SentryExtraContextProvider(crashWrapper: Dependencies.crashWrapper, processInfoWrapper: Dependencies.processInfoWrapper)
#endif

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
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
#endif
    
    private var crashIntegrationSessionHandler: SentryCrashIntegrationSessionHandler?
    func getCrashIntegrationSessionBuilder(_ options: Options) -> SentryCrashIntegrationSessionHandler? {
        getOptionalLazyVar(\.crashIntegrationSessionHandler) {
            
            guard let fileManager = fileManager else {
                SentrySDKLog.fatal("File manager is not available")
                return nil
            }
            
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
            let watchdogLogic = SentryWatchdogTerminationLogic(options: options,
                                                       crashAdapter: crashWrapper,
                                                       appStateManager: appStateManager)
            return SentryCrashIntegrationSessionHandler(
                crashWrapper: crashWrapper,
                watchdogTerminationLogic: watchdogLogic,
                fileManager: fileManager
            )
#else
            return SentryCrashIntegrationSessionHandler(crashWrapper: crashWrapper, fileManager: fileManager)
#endif
        }
    }

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
    private var _screenshotSource: SentryScreenshotSource?
    @objc public lazy var screenshotSource: SentryScreenshotSource? = getOptionalLazyVar(\._screenshotSource) {
        // The options could be null here, but this is a general issue in the dependency
        // container and will be fixed in a future refactoring.
        guard let options = SentrySDK.startOption else {
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
        let release = SentrySDK.startOption?.releaseName
        return SentryAppStateManager(
            releaseName: release,
            crashWrapper: crashWrapper,
            fileManager: fileManager,
            sysctlWrapper: sysctlWrapper)
    }
    private var _crashReporter: SentryCrashSwift?
    @objc public lazy var crashReporter = getLazyVar(\._crashReporter) {
        SentryCrashSwift(with: SentrySDK.startOption?.cacheDirectoryPath)
    }
    
    private var anrTracker: SentryANRTracker?
    @objc public func getANRTracker(_ timeout: TimeInterval) -> SentryANRTracker {
        getLazyVar(\.anrTracker) {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
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
}

#if os(iOS) && !SENTRY_NO_UIKIT
extension SentryDependencyContainer: ScreenshotSourceProvider { }
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

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
protocol FramesTrackingProvider {
    var framesTracker: SentryFramesTracker { get }
}

extension SentryDependencyContainer: FramesTrackingProvider { }
#endif

#if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)
protocol NotificationCenterProvider {
    var notificationCenterWrapper: SentryNSNotificationCenterWrapper { get }
}

extension SentryDependencyContainer: NotificationCenterProvider { }
#endif

#if (os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UIKIT
protocol ScreenshotIntegrationProvider {
    var screenshotSource: SentryScreenshotSource? { get }
}

extension SentryDependencyContainer: ScreenshotIntegrationProvider { }

protocol ViewHierarchyProviderProvider {
    var viewHierarchyProvider: SentryViewHierarchyProvider? { get }
}

extension SentryDependencyContainer: ViewHierarchyProviderProvider { }
#endif

protocol DispatchQueueWrapperProvider {
    var dispatchQueueWrapper: SentryDispatchQueueWrapper { get }
}
extension SentryDependencyContainer: DispatchQueueWrapperProvider { }

protocol CrashWrapperProvider {
    var crashWrapper: SentryCrashWrapper { get }
}
extension SentryDependencyContainer: CrashWrapperProvider { }

protocol ExtensionDetectorProvider {
    var extensionDetector: SentryExtensionDetector { get }
}
extension SentryDependencyContainer: ExtensionDetectorProvider { }

protocol DebugImageProvider {
    var debugImageProvider: SentryDebugImageProvider { get }
}
extension SentryDependencyContainer: DebugImageProvider { }

protocol ThreadInspectorProvider {
    var threadInspector: SentryThreadInspector { get }
}
extension SentryDependencyContainer: ThreadInspectorProvider { }

protocol FileManagerProvider {
    var fileManager: SentryFileManager? { get }
}
extension SentryDependencyContainer: FileManagerProvider { }

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

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
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
    func getCrashIntegrationSessionBuilder(_ options: Options) -> SentryCrashIntegrationSessionHandler?
}
extension SentryDependencyContainer: CrashIntegrationSessionHandlerBuilder {}

protocol CrashInstallationReporterBuilder {
    func getCrashInstallationReporter(_ options: Options) -> SentryCrashInstallationReporter
}
extension SentryDependencyContainer: CrashInstallationReporterBuilder {}

//swiftlint:enable file_length missing_docs
