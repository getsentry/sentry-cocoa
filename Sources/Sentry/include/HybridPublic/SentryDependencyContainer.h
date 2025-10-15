#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

@class SentryBinaryImageCache;
@class SentryCrash;
@class SentryCrashWrapper;
@class SentryDebugImageProvider;
@class SentryDispatchFactory;
@class SentryDispatchQueueWrapper;
@class SentryExtraContextProvider;
@class SentryFileManager;
@class SentryNSTimerFactory;
@class SentrySwizzleWrapper;
@class SentrySysctl;
@class SentryThreadsafeApplication;
@class SentrySystemWrapper;
@class SentryThreadWrapper;
@class SentryFileIOTracker;
@class SentryScopePersistentStore;
@class SentryOptions;
@class SentrySessionTracker;
@class SentryGlobalEventProcessor;
@class SentryThreadInspector;
@class SentryReachability;

@protocol SentryAppStateManager;
@protocol SentryANRTracker;
@protocol SentryRandomProtocol;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;
@protocol SentryApplication;
@protocol SentryProcessInfoSource;
@protocol SentryNSNotificationCenterWrapper;
@protocol SentryObjCRuntimeWrapper;
@protocol SentryInfoPlistWrapperProvider;
@protocol SentrySessionReplayEnvironmentCheckerProvider;

#if SENTRY_HAS_METRIC_KIT
@class SentryMXManager;
#endif // SENTRY_HAS_METRIC_KIT

#if SENTRY_UIKIT_AVAILABLE
@class SentryFramesTracker;
@class SentryScreenshotSource;
@class SentryViewHierarchyProvider;
@class SentryUIViewControllerPerformanceTracker;
@class SentryWatchdogTerminationAttributesProcessor;
@protocol SentryScopeObserver;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_HAS_UIKIT
@protocol SentryUIDeviceWrapper;
#endif // TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/**
 * The dependency container is optimized to use as few locks as possible and to only keep the
 * required dependencies in memory. It splits its dependencies into two groups.
 *
 * Init Dependencies: These are mandatory dependencies required to run the SDK, no matter the
 * options. The dependency container initializes them in init and uses no locks for efficiency.
 *
 * Lazy Dependencies: These dependencies either have some state or aren't always required and,
 * therefore, get initialized lazily to minimize the memory footprint.
 */
@interface SentryDependencyContainer : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

/**
 * Resets all dependencies.
 */
+ (void)reset;

#pragma mark - Init Dependencies

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) id<SentryRandomProtocol> random;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;
@property (nonatomic, strong) id<SentryCurrentDateProvider> dateProvider;
@property (nonatomic, strong) SentryExtraContextProvider *extraContextProvider;
@property (nonatomic, strong) id<SentryNSNotificationCenterWrapper> notificationCenterWrapper;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) id<SentryProcessInfoSource> processInfoWrapper;
@property (nonatomic, strong) SentrySysctl *sysctlWrapper;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;
@property (nonatomic, strong) SentryThreadsafeApplication *threadsafeApplication;
@property (nonatomic, strong) id<SentryInfoPlistWrapperProvider> infoPlistWrapper;
@property (nonatomic, strong) id<SentrySessionReplayEnvironmentCheckerProvider>
    sessionReplayEnvironmentChecker;

@property (nonatomic, strong) SentryReachability *reachability;

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) id<SentryUIDeviceWrapper> uiDeviceWrapper;
#endif // TARGET_OS_IOS

#pragma mark - Lazy Dependencies

@property (nonatomic, strong, nullable) SentryFileManager *fileManager;
@property (nonatomic, strong) id<SentryAppStateManager> appStateManager;
@property (nonatomic, strong, readonly) SentryThreadInspector *threadInspector;
@property (nonatomic, strong, readonly) SentryFileIOTracker *fileIOTracker;
@property (nonatomic, strong) SentryCrash *crashReporter;
@property (nonatomic, strong) SentryScopePersistentStore *scopePersistentStore;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout;
#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout isV2Enabled:(BOOL)isV2Enabled;
#endif // SENTRY_HAS_UIKIT

- (nullable id<SentryApplication>)application;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, strong) SentrySystemWrapper *systemWrapper;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, strong) SentryDispatchFactory *dispatchFactory;
@property (nonatomic, strong) SentryNSTimerFactory *timerFactory;

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
#if SENTRY_UIKIT_AVAILABLE
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, strong) SentryViewHierarchyProvider *viewHierarchyProvider;
@property (nonatomic, strong)
    SentryUIViewControllerPerformanceTracker *uiViewControllerPerformanceTracker;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_TARGET_REPLAY_SUPPORTED
@property (nonatomic, strong) SentryScreenshotSource *screenshotSource;
#endif // SENTRY_TARGET_REPLAY_SUPPORTED

#if SENTRY_HAS_METRIC_KIT
@property (nonatomic, strong) SentryMXManager *metricKitManager API_UNAVAILABLE(tvos, watchos);
#endif // SENTRY_HAS_METRIC_KIT
@property (nonatomic, strong) id<SentryObjCRuntimeWrapper> objcRuntimeWrapper;

#if SENTRY_HAS_UIKIT
- (id<SentryScopeObserver>)getWatchdogTerminationScopeObserverWithOptions:(SentryOptions *)options;
@property (nonatomic, strong)
    SentryWatchdogTerminationAttributesProcessor *watchdogTerminationAttributesProcessor;
#endif

@property (nonatomic, strong) SentryGlobalEventProcessor *globalEventProcessor;
- (SentrySessionTracker *)getSessionTrackerWithOptions:(SentryOptions *)options;

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
// Some tests rely on this value being grabbed from the global dependency container
// rather than using dependency injection.
@property (nonatomic, strong) id<SentryApplication> applicationOverride;
#endif

@end

NS_ASSUME_NONNULL_END
