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
 * Macro for implementing double-checked locking pattern for lazy initialization.
 */
#define SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(instance, initBlock)                                  \
    if (instance == nil) {                                                                         \
        @synchronized(sentryDependencyContainerLock) {                                             \
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
static NSObject *sentryDependencyContainerLock;

+ (void)initialize
{
    if (self == [SentryDependencyContainer class]) {
        instance = [[SentryDependencyContainer alloc] init];
        sentryDependencyContainerLock = [[NSObject alloc] init];
    }
}

+ (instancetype)sharedInstance
{
    return instance;
}

+ (void)reset
{
    @synchronized(sentryDependencyContainerLock) {
#if SENTRY_HAS_REACHABILITY
        [instance->_reachability removeAllObservers];
#endif // !TARGET_OS_WATCH

#if SENTRY_HAS_UIKIT
        [instance->_framesTracker stop];
#endif // SENTRY_HAS_UIKIT

        instance->_fileManager = nil;
        instance->_appStateManager = nil;
        instance->_threadInspector = nil;
        instance->_fileIOTracker = nil;
        instance->_crashReporter = nil;
        instance->_anrTracker = nil;
    }
}

+ (void)resetForTests
{
    NSAssert([NSThread isMainThread],
        @"You must call this method on the main thread, because initDependencies isn't thread safe "
        @"even though we call it inside synchronized block. We access the instance with no locks "
        @"in sharedInstance, and all properties set in initDependencies use no locks for "
        @"efficiency. So, when some background thread accesses a dependency set in "
        @"initDependencies while this method runs, we end up in a race condition and could crash. "
        @"We expect this method only to be called on the main thread when clearing down tests. "
        @"This assert is a safety guard.");

    @synchronized(sentryDependencyContainerLock) {
        [self reset];

        [instance initDependencies];

        instance->_swizzleWrapper = nil;
        instance->_systemWrapper = nil;
        instance->_dispatchFactory = nil;
        instance->_timerFactory = nil;

#if SENTRY_UIKIT_AVAILABLE
        instance->_framesTracker = nil;
        instance->_screenshot = nil;
        instance->_viewHierarchy = nil;
        instance->_application = nil;
        instance->_uiViewControllerPerformanceTracker = nil;
#endif // SENTRY_UIKIT_AVAILABLE

#if SENTRY_HAS_METRIC_KIT
        instance->_metricKitManager = nil;
#endif
    }
}

- (instancetype)init
{
    if (self = [super init]) {
        [self initDependencies];
    }
    return self;
}

- (void)initDependencies
{
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
#if SENTRY_HAS_UIKIT
    _uiDeviceWrapper = [[SentryUIDeviceWrapper alloc] init];
    _application = [[SentryUIApplication alloc] init];
#endif // SENTRY_HAS_UIKIT

#if SENTRY_HAS_REACHABILITY
    _reachability = [[SentryReachability alloc] init];
#endif // !SENTRY_HAS_REACHABILITY
}

#pragma mark - Stateful Dependencies

- (SentryFileManager *)fileManager
{
    @synchronized(sentryDependencyContainerLock) {
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

- (SentryAppStateManager *)appStateManager
{
    @synchronized(sentryDependencyContainerLock) {
        if (_appStateManager == nil) {
            _appStateManager =
                [[SentryAppStateManager alloc] initWithOptions:SentrySDK.options
                                                  crashWrapper:self.crashWrapper
                                                   fileManager:self.fileManager
                                          dispatchQueueWrapper:self.dispatchQueueWrapper
                                     notificationCenterWrapper:self.notificationCenterWrapper];
        }
        return _appStateManager;
    }
}

- (SentryThreadInspector *)threadInspector
{
    @synchronized(sentryDependencyContainerLock) {
        if (_threadInspector == nil) {
            _threadInspector = [[SentryThreadInspector alloc] initWithOptions:SentrySDK.options];
        }
        return _threadInspector;
    }
}

- (SentryFileIOTracker *)fileIOTracker
{
    @synchronized(sentryDependencyContainerLock) {
        if (_fileIOTracker == nil) {
            _fileIOTracker =
                [[SentryFileIOTracker alloc] initWithThreadInspector:[self threadInspector]
                                                  processInfoWrapper:[self processInfoWrapper]];
        }

        return _fileIOTracker;
    }
}

- (SentryCrash *)crashReporter
{
    @synchronized(sentryDependencyContainerLock) {
        if (_crashReporter == nil) {
            _crashReporter =
                [[SentryCrash alloc] initWithBasePath:SentrySDK.options.cacheDirectoryPath];
        }

        return _crashReporter;
    }
}

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
{
    @synchronized(sentryDependencyContainerLock) {
        if (_anrTracker == nil) {
            _anrTracker =
                [[SentryANRTrackerV1 alloc] initWithTimeoutInterval:timeout
                                                       crashWrapper:self.crashWrapper
                                               dispatchQueueWrapper:self.dispatchQueueWrapper
                                                      threadWrapper:self.threadWrapper];
        }
        return _anrTracker;
    }
}

#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout isV2Enabled:(BOOL)isV2Enabled
{
    if (isV2Enabled) {
        @synchronized(sentryDependencyContainerLock) {
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

#pragma mark - Lazy Dependencies

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (SentryScreenshot *)screenshot
{
#    if SENTRY_HAS_UIKIT
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_screenshot, [[SentryScreenshot alloc] init]);

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

    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_viewHierarchy, [[SentryViewHierarchy alloc] init]);
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
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_uiViewControllerPerformanceTracker,
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
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_framesTracker,
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
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_swizzleWrapper, [[SentrySwizzleWrapper alloc] init]);
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
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_systemWrapper, [[SentrySystemWrapper alloc] init]);
}

- (SentryDispatchFactory *)dispatchFactory SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_dispatchFactory, [[SentryDispatchFactory alloc] init]);
}

- (SentryNSTimerFactory *)timerFactory SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(_timerFactory, [[SentryNSTimerFactory alloc] init]);
}

#if SENTRY_HAS_METRIC_KIT
- (SentryMXManager *)metricKitManager SENTRY_DISABLE_THREAD_SANITIZER(
    "Double-checked locks produce false alarms.")
{
    // Disable crash diagnostics as we only use it for validation of the symbolication
    // of stacktraces, because crashes are easy to trigger for MetricKit. We don't want
    // crash reports of MetricKit in production as we have SentryCrash.
    SENTRY_DOUBLE_CHECKED_LOCK_LAZY_INIT(
        _metricKitManager, [[SentryMXManager alloc] initWithDisableCrashDiagnostics:YES]);
}

#endif // SENTRY_HAS_METRIC_KIT

@end
