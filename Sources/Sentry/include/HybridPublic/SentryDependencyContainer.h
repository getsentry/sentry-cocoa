#if __has_include(<Sentry/SentryDefines.h>)
#    import <Sentry/SentryDefines.h>
#else
#    import "SentryDefines.h"
#endif

@protocol SentryANRTracker;
@class SentryAppStateManager;
@class SentryBinaryImageCache;
@class SentryCrash;
@class SentryCrashWrapper;
@class SentryDebugImageProvider;
@class SentryDispatchFactory;
@class SentryDispatchQueueWrapper;
@class SentryExtraContextProvider;
@class SentryFileManager;
@class SentryNSNotificationCenterWrapper;
@class SentryNSProcessInfoWrapper;
@class SentryNSTimerFactory;
@class SentrySwizzleWrapper;
@class SentrySysctl;
@class SentrySystemWrapper;
@class SentryThreadWrapper;
@class SentryThreadInspector;
@class SentryFileIOTracker;
@protocol SentryRandom;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;

#if SENTRY_HAS_METRIC_KIT
@class SentryMXManager;
#endif // SENTRY_HAS_METRIC_KIT

#if SENTRY_UIKIT_AVAILABLE
@class SentryFramesTracker;
@class SentryScreenshot;
@class SentryUIApplication;
@class SentryViewHierarchy;
@class SentryUIViewControllerPerformanceTracker;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_HAS_UIKIT
@class SentryUIDeviceWrapper;
#endif // TARGET_OS_IOS

#if !TARGET_OS_WATCH
@class SentryReachability;
#endif // !TARGET_OS_WATCH

NS_ASSUME_NONNULL_BEGIN

/**
 * The dependency container is optimized to use as few locks as possible and to only keep the
 * required dependencies in memory. It splits its dependencies into three different groups.
 *
 * Init Dependencies: These are mandatory dependencies required to run the SDK, no matter the
 * options. The dependency container initializes them in init and uses no locks for efficiency, and
 * it doesn't clear them when reset is called, because this would require locks.
 *
 * Stateful Dependencies: These dependencies have some state from the options, such as the DSN or
 * other flags. The dependency container must clear these on reset, which always requires a lock
 * when accessing them. We can't use a double-checked lock, because when you set the property to
 * nil, the double-checked lock doesn't work, because the property could get set to nil in between
 * checking for nil and returning it.
 *
 * Lazy Dependencies: These dependencies don't have any state and aren't always required. We don't
 * initialize these in init dependencies to minimize the memory footprint. The class uses a
 * double-checked lock to minimize locks when accessing these.
 */
@interface SentryDependencyContainer : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

/**
 * Resets stateful dependencies to nil.
 */
+ (void)reset;

/**
 * Restes all dependencies.
 */
+ (void)resetForTests;

#pragma mark - Init Dependencies
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) id<SentryRandom> random;
@property (nonatomic, strong) SentryThreadWrapper *threadWrapper;
@property (nonatomic, strong) SentryBinaryImageCache *binaryImageCache;
@property (nonatomic, strong) id<SentryCurrentDateProvider> dateProvider;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;
@property (nonatomic, strong) SentryExtraContextProvider *extraContextProvider;
@property (nonatomic, strong) SentryNSNotificationCenterWrapper *notificationCenterWrapper;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryNSProcessInfoWrapper *processInfoWrapper;
@property (nonatomic, strong) SentrySysctl *sysctlWrapper;
@property (nonatomic, strong) id<SentryRateLimits> rateLimits;

#if SENTRY_HAS_UIKIT
@property (nonatomic, strong) SentryUIDeviceWrapper *uiDeviceWrapper;
#endif // TARGET_OS_IOS

#if !TARGET_OS_WATCH
@property (nonatomic, strong) SentryReachability *reachability;
#endif // !TARGET_OS_WATCH

#pragma mark - Stateful Dependencies
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;
@property (nonatomic, strong) SentryFileIOTracker *fileIOTracker;
@property (nonatomic, strong) SentryCrash *crashReporter;

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout;
#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout isV2Enabled:(BOOL)isV2Enabled;
#endif // SENTRY_HAS_UIKIT

#pragma mark - Lazy Dependencies

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;
@property (nonatomic, strong) SentrySystemWrapper *systemWrapper;
@property (nonatomic, strong) SentryDispatchFactory *dispatchFactory;
@property (nonatomic, strong) SentryNSTimerFactory *timerFactory;

#if SENTRY_UIKIT_AVAILABLE
@property (nonatomic, strong) SentryFramesTracker *framesTracker;
@property (nonatomic, strong) SentryScreenshot *screenshot;
@property (nonatomic, strong) SentryViewHierarchy *viewHierarchy;
@property (nonatomic, strong) SentryUIApplication *application;
@property (nonatomic, strong)
    SentryUIViewControllerPerformanceTracker *uiViewControllerPerformanceTracker;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_HAS_METRIC_KIT
@property (nonatomic, strong) SentryMXManager *metricKitManager API_AVAILABLE(
    ios(15.0), macos(12.0), macCatalyst(15.0)) API_UNAVAILABLE(tvos, watchos);
#endif // SENTRY_HAS_METRIC_KIT

@end

NS_ASSUME_NONNULL_END
