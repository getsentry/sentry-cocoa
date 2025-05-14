#import "SentryANRTrackerV1.h"

#import "SentryBinaryImageCache.h"
#import "SentryDispatchFactory.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryExtraContextProvider.h"
#import "SentryFileIOTracker.h"
#import "SentryFileManager.h"
#import "SentryInternalCDefines.h"
#import "SentryLog.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryNSTimerFactory.h"
#import "SentryOptions+Private.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"
#import "SentrySystemWrapper.h"
#import "SentryThreadInspector.h"
#import "SentryUIDeviceWrapper.h"
#import <SentryAppStateManager.h>
#import <SentryCrash.h>
#import <SentryCrashWrapper.h>
#import <SentryDebugImageProvider.h>
#import <SentryDefaultRateLimits.h>
#import <SentryDependencyContainer.h>
#import <SentryHttpDateParser.h>
#import <SentryNSNotificationCenterWrapper.h>
#import <SentryPerformanceTracker.h>
#import <SentryRateLimitParser.h>
#import <SentryRetryAfterHeaderParser.h>
#import <SentrySDK+Private.h>
#import <SentrySwift.h>
#import <SentrySwizzleWrapper.h>
#import <SentrySysctl.h>
#import <SentryThreadWrapper.h>
#import <SentryTracer.h>
#import <SentryUIViewControllerPerformanceTracker.h>

#if SENTRY_HAS_UIKIT
#    import "SentryANRTrackerV2.h"
#    import "SentryFramesTracker.h"
#    import "SentryUIApplication.h"
#    import <SentryScreenshot.h>
#    import <SentryViewHierarchy.h>
#endif // SENTRY_HAS_UIKIT

#if TARGET_OS_IOS
#    import "SentryUIDeviceWrapper.h"
#endif // TARGET_OS_IOS

#if !TARGET_OS_WATCH
#    import "SentryReachability.h"
#endif // !TARGET_OS_WATCH

/**
 * Macro for implementing lazy initialization with a double-checked lock. The double-checked lock
 * speeds up the dependency retrieval by around 5%, so it's worth having it. Measured with
 * self.measure in unit tests.
 */
#define SENTRY_LAZY_INIT(instance, initBlock)                                                      \
    if (instance == nil) {                                                                         \
        @synchronized(sentryDependencyContainerDependenciesLock) {                                 \
            if (instance == nil) {                                                                 \
                instance = initBlock;                                                              \
            }                                                                                      \
        }                                                                                          \
    }                                                                                              \
    return instance;

@interface SentryDependencyContainer ()

@property (nonatomic, strong) id<SentryANRTracker> anrTracker;

@end

@implementation SentryDependencyContainer

static SentryDependencyContainer *instance;
static NSObject *sentryDependencyContainerDependenciesLock;
static NSObject *sentryDependencyContainerInstanceLock;

+ (void)initialize
{
    if (self == [SentryDependencyContainer class]) {
        instance = [[SentryDependencyContainer alloc] init];
        // We use two locks, because we don't want the dependencies to block the instance lock.
        // Using two locks speeds up the accessing the dependencies around 5%, which is worth having
        // the extra lock. Measured with self.measure in unit tests.
        sentryDependencyContainerInstanceLock = [[NSObject alloc] init];
        sentryDependencyContainerDependenciesLock = [[NSObject alloc] init];
    }
}

+ (instancetype)sharedInstance
{
    // This synchronization adds around 5% slowdown compared to no synchronization.
    // As we don't call this method in a tight loop, it's acceptable. Measured with self.measure in
    // unit tests.
    @synchronized(sentryDependencyContainerInstanceLock) {
        return instance;
    }
}

+ (void)reset
{
    @synchronized(sentryDependencyContainerInstanceLock) {
#if SENTRY_HAS_REACHABILITY
        [instance->_reachability removeAllObservers];
#endif // !TARGET_OS_WATCH

#if SENTRY_HAS_UIKIT
        [instance->_framesTracker stop];
#endif // SENTRY_HAS_UIKIT

        instance = [[SentryDependencyContainer alloc] init];
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        _dispatchQueueWrapper = [[SentryDispatchQueueWrapper alloc] init];
        _random = [[SentryRandom alloc] init];
        _threadWrapper = [[SentryThreadWrapper alloc] init];
        _binaryImageCache = [[SentryBinaryImageCache alloc] init];
        _dateProvider = [[SentryDefaultCurrentDateProvider alloc] init];
        _debugImageProvider = [[SentryDebugImageProvider alloc] init];
        _extraContextProvider = [[SentryExtraContextProvider alloc] init];
        _notificationCenterWrapper = [[SentryNSNotificationCenterWrapper alloc] init];
        _crashWrapper = [[SentryCrashWrapper alloc] init];
        _processInfoWrapper = [[SentryNSProcessInfoWrapper alloc] init];
        _sysctlWrapper = [[SentrySysctl alloc] init];

        SentryRetryAfterHeaderParser *retryAfterHeaderParser = [[SentryRetryAfterHeaderParser alloc]
            initWithHttpDateParser:[[SentryHttpDateParser alloc] init]
               currentDateProvider:_dateProvider];
        SentryRateLimitParser *rateLimitParser =
            [[SentryRateLimitParser alloc] initWithCurrentDateProvider:_dateProvider];

        _rateLimits =
            [[SentryDefaultRateLimits alloc] initWithRetryAfterHeaderParser:retryAfterHeaderParser
                                                         andRateLimitParser:rateLimitParser
                                                        currentDateProvider:_dateProvider];

#if SENTRY_HAS_REACHABILITY
        _reachability = [[SentryReachability alloc] init];
#endif // !SENTRY_HAS_REACHABILITY

#if SENTRY_HAS_UIKIT
        _uiDeviceWrapper = [[SentryUIDeviceWrapper alloc] init];
        _application = [[SentryUIApplication alloc] init];
#endif // SENTRY_HAS_UIKIT
    }
    return self;
}

- (SentryFileManager *)fileManager SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    @synchronized(sentryDependencyContainerDependenciesLock) {
        if (_fileManager == nil) {
            NSError *error;
            _fileManager = [[SentryFileManager alloc] initWithOptions:SentrySDK.options
                                                                error:&error];
            if (_fileManager == nil) {
                SENTRY_LOG_DEBUG(@"Could not create file manager - %@", error);
            }
        }

        return _fileManager;
    }
}

- (SentryAppStateManager *)appStateManager SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_appStateManager,
        [[SentryAppStateManager alloc] initWithOptions:SentrySDK.options
                                          crashWrapper:self.crashWrapper
                                           fileManager:self.fileManager
                                  dispatchQueueWrapper:self.dispatchQueueWrapper
                             notificationCenterWrapper:self.notificationCenterWrapper]);
}

- (SentryThreadInspector *)threadInspector SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(
        _threadInspector, [[SentryThreadInspector alloc] initWithOptions:SentrySDK.options]);
}

- (SentryFileIOTracker *)fileIOTracker SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_fileIOTracker,
        [[SentryFileIOTracker alloc] initWithThreadInspector:[self threadInspector]
                                          processInfoWrapper:[self processInfoWrapper]]);
}

- (SentryCrash *)crashReporter SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_crashReporter,
        [[SentryCrash alloc] initWithBasePath:SentrySDK.options.cacheDirectoryPath]);
}

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
    SENTRY_DISABLE_THREAD_SANITIZER("Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_anrTracker,
        [[SentryANRTrackerV1 alloc] initWithTimeoutInterval:timeout
                                               crashWrapper:self.crashWrapper
                                       dispatchQueueWrapper:self.dispatchQueueWrapper
                                              threadWrapper:self.threadWrapper]);
}

#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
                          isV2Enabled:(BOOL)isV2Enabled
    SENTRY_DISABLE_THREAD_SANITIZER("Double-checked locks produce false alarms.")
{
    if (isV2Enabled) {
        @synchronized(sentryDependencyContainerDependenciesLock) {
            if (_anrTracker == nil) {
                _anrTracker =
                    [[SentryANRTrackerV2 alloc] initWithTimeoutInterval:timeout
                                                           crashWrapper:self.crashWrapper
                                                   dispatchQueueWrapper:self.dispatchQueueWrapper
                                                          threadWrapper:self.threadWrapper
                                                          framesTracker:self.framesTracker];
            }
            return _anrTracker;
        }
    } else {
        return [self getANRTracker:timeout];
    }
}
#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (SentryScreenshot *)screenshot SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_screenshot, [[SentryScreenshot alloc] init]);
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.screenshot only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}
#endif

#if SENTRY_UIKIT_AVAILABLE
- (SentryViewHierarchy *)viewHierarchy SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
#    if SENTRY_HAS_UIKIT

    SENTRY_LAZY_INIT(_viewHierarchy, [[SentryViewHierarchy alloc] init]);
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.viewHierarchy only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryUIViewControllerPerformanceTracker *)
    uiViewControllerPerformanceTracker SENTRY_DISABLE_THREAD_SANITIZER(
        "Double-checked locks produce false alarms.")
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_uiViewControllerPerformanceTracker,
        [[SentryUIViewControllerPerformanceTracker alloc]
                 initWithTracker:SentryPerformanceTracker.shared
            dispatchQueueWrapper:[self dispatchQueueWrapper]]);
#    else
    SENTRY_LOG_DEBUG(@"SentryDependencyContainer.uiViewControllerPerformanceTracker only works "
                     @"with UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryFramesTracker *)framesTracker SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_framesTracker,
        [[SentryFramesTracker alloc]
            initWithDisplayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]
                          dateProvider:self.dateProvider
                  dispatchQueueWrapper:self.dispatchQueueWrapper
                    notificationCenter:self.notificationCenterWrapper
             keepDelayedFramesDuration:SENTRY_AUTO_TRANSACTION_MAX_DURATION]);

#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.framesTracker only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentrySwizzleWrapper *)swizzleWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
#    if SENTRY_HAS_UIKIT
    SENTRY_LAZY_INIT(_swizzleWrapper, [[SentrySwizzleWrapper alloc] init]);
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.swizzleWrapper only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}
#endif // SENTRY_UIKIT_AVAILABLE

- (SentrySystemWrapper *)systemWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_systemWrapper, [[SentrySystemWrapper alloc] init]);
}

- (SentryDispatchFactory *)dispatchFactory SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_dispatchFactory, [[SentryDispatchFactory alloc] init]);
}

- (SentryNSTimerFactory *)timerFactory SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_LAZY_INIT(_timerFactory, [[SentryNSTimerFactory alloc] init]);
}

#if SENTRY_HAS_METRIC_KIT
- (SentryMXManager *)metricKitManager SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    // Disable crash diagnostics as we only use it for validation of the symbolication
    // of stacktraces, because crashes are easy to trigger for MetricKit. We don't want
    // crash reports of MetricKit in production as we have SentryCrash.
    SENTRY_LAZY_INIT(
        _metricKitManager, [[SentryMXManager alloc] initWithDisableCrashDiagnostics:YES]);
}

#endif // SENTRY_HAS_METRIC_KIT

@end
