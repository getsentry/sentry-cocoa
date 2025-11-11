@_implementationOnly import _SentryPrivate
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
import UIKit
#endif

// Declare the application provider block at the top level to prevent capturing 'self'
// from the dependency container, which would create cyclic dependencies and memory leaks.
let defaultApplicationProvider: () -> SentryApplication? = {
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
    return UIApplication.shared
#elseif os(macOS)
    return NSApplication.shared
#else
    return nil
#endif
}

let SENTRY_AUTO_TRANSACTION_MAX_DURATION = 500.0

// MARK: - RedactWrapper

final class RedactWrapper: SentryRedactOptions {
    var maskAllText: Bool {
        defaultOptions.maskAllText
    }
    
    var maskAllImages: Bool {
        defaultOptions.maskAllImages
    }
    
    var maskedViewClasses: [AnyClass] {
        defaultOptions.maskedViewClasses
    }
    
    var unmaskedViewClasses: [AnyClass] {
        defaultOptions.unmaskedViewClasses
    }
    
    private let defaultOptions: SentryDefaultRedactOptions
    init(_ defaultOptions: SentryDefaultRedactOptions) {
        self.defaultOptions = defaultOptions
    }
}

// MARK: - Extensions

extension SentryFileManager: SentryFileManagerProtocol { }
@_spi(Private) extension SentryANRTrackerV1: SentryANRTrackerInternalProtocol { }

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
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
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
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
    
    @objc(getSessionTrackerWithOptions:) public func getSessionTracker(with options: Options) -> SessionTracker {
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
    @objc public var rateLimits: RateLimits = DefaultRateLimits(
        retryAfterHeaderParser: RetryAfterHeaderParser(httpDateParser: HttpDateParser(), currentDateProvider: Dependencies.dateProvider),
        andRateLimitParser: RateLimitParser(currentDateProvider: Dependencies.dateProvider),
        currentDateProvider: Dependencies.dateProvider)
    @objc public var reachability = SentryReachability()
    @objc public var sysctlWrapper = Dependencies.sysctlWrapper
    @objc public var sessionReplayEnvironmentChecker: SentrySessionReplayEnvironmentCheckerProvider = Dependencies.sessionReplayEnvironmentChecker
    @objc public var debugImageProvider = Dependencies.debugImageProvider
    @objc public var objcRuntimeWrapper: SentryObjCRuntimeWrapper = SentryDefaultObjCRuntimeWrapper()
    
#if os(iOS) && !SENTRY_NO_UIKIT
    @objc public var extraContextProvider = SentryExtraContextProvider(crashWrapper: Dependencies.crashWrapper, processInfoWrapper: Dependencies.processInfoWrapper, deviceWrapper: Dependencies.uiDeviceWrapper)
#else
    @objc public var extraContextProvider = SentryExtraContextProvider(crashWrapper: Dependencies.crashWrapper, processInfoWrapper: Dependencies.processInfoWrapper)
#endif
    
#if os(iOS) || os(macOS)
    // Disable crash diagnostics as we only use it for validation of the symbolication
    // of stacktraces, because crashes are easy to trigger for MetricKit. We don't want
    // crash reports of MetricKit in production as we have SentryCrash.
    @objc public var metricKitManager = SentryMXManager(disableCrashDiagnostics: true)
#endif

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
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
        let delayedFramesTracker = SentryDelayedFramesTracker(keepDelayedFramesDuration: SENTRY_AUTO_TRANSACTION_MAX_DURATION)
        return SentryFramesTracker(displayLinkWrapper: SentryDisplayLinkWrapper(), dateProvider: dateProvider, dispatchQueueWrapper: dispatchQueueWrapper, notificationCenter: notificationCenterWrapper, delayedFramesTracker: delayedFramesTracker)
    }
    
    private var _viewHierarchyProvider: SentryViewHierarchyProvider?
    @objc public lazy var viewHierarchyProvider = getLazyVar(\._viewHierarchyProvider) {
        SentryViewHierarchyProvider(dispatchQueueWrapper: dispatchQueueWrapper, applicationProvider: defaultApplicationProvider)
    }
    
    @objc public func getWatchdogTerminationScopeObserverWithOptions(_ options: Options) -> SentryScopeObserver {
         return SentryWatchdogTerminationScopeObserver(
            breadcrumbProcessor: SentryWatchdogTerminationBreadcrumbProcessor(
                maxBreadcrumbs: Int(options.maxBreadcrumbs)),
            attributesProcessor: watchdogTerminationAttributesProcessor)
    }
#endif

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
    private var _screenshotSource: SentryScreenshotSource?
    @objc public lazy var screenshotSource: SentryScreenshotSource? = getOptionalLazyVar(\._screenshotSource) {
        // The options could be null here, but this is a general issue in the dependency
        // container and will be fixed in a future refactoring.
        guard let options = SentrySDKInternal.optionsInternal else {
            return nil
        }
        
        let viewRenderer: SentryViewRenderer
        if SentryDependencyContainerSwiftHelper.viewRendererV2Enabled(options) {
            viewRenderer = SentryViewRendererV2(enableFastViewRendering: SentryDependencyContainerSwiftHelper.fastViewRenderingEnabled(options))
        } else {
            viewRenderer = SentryDefaultViewRenderer()
        }

        let redactBuilder: SentryUIRedactBuilderProtocol
        guard let maskingStrategy = SentrySessionReplayMaskingStrategy(rawValue: Int(SentryDependencyContainerSwiftHelper.getSessionReplayMaskingStrategy(options))) else {
            SentrySDKLog.error("Failed to parse session replay masking strategy from options")
            return nil
        }
        let redactOptions = RedactWrapper(SentryDependencyContainerSwiftHelper.redactOptions(options))
        switch maskingStrategy {
        case .accessibility:
            redactBuilder = SentryAccessibilityRedactBuilder(options: redactOptions)
        case .defensive:
            redactBuilder = SentryDefensiveRedactBuilder(options: redactOptions)
        case .machineLearning:
            redactBuilder = SentryMLRedactBuilder(options: redactOptions)
        case .pdf:
            redactBuilder = SentryPDFRedactBuilder(options: redactOptions)
        case .viewHierarchy:
            redactBuilder = SentryUIRedactBuilder(options: redactOptions)
        case .wireframe:
            redactBuilder = SentryWireframeRedactBuilder(options: redactOptions)
        }

        let photographer = SentryViewPhotographer(
            renderer: viewRenderer,
            redactBuilder: redactBuilder,
            enableMaskRendererV2: SentryDependencyContainerSwiftHelper.viewRendererV2Enabled(options)
        )
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
        var release: String?
        if let options = SentrySDKInternal.optionsInternal {
            release = SentryDependencyContainerSwiftHelper.release(options)
        }
        return SentryAppStateManager(
            releaseName: release,
            crashWrapper: crashWrapper,
            fileManager: fileManager,
            sysctlWrapper: sysctlWrapper)
    }
    private var _crashReporter: SentryCrashSwift?
    @objc public lazy var crashReporter = getLazyVar(\._crashReporter) {
        SentryCrashSwift(with: SentrySDKInternal.optionsInternal.map { SentryDependencyContainerSwiftHelper.cacheDirectoryPath($0) })
    }
    
    private var anrTracker: SentryANRTracker?
    @objc public func getANRTracker(_ timeout: TimeInterval) -> SentryANRTracker {
        getLazyVar(\.anrTracker) {
        #if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
            SentryANRTracker(helper: SentryANRTrackerV2(timeoutInterval: timeout))
        #else
            SentryANRTracker(helper: SentryANRTrackerV1(timeoutInterval: timeout))
        #endif
        }
    }
}
