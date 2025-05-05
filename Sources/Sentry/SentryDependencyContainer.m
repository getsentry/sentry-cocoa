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
#import "SentrySysctl.h"
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

@interface SentryDependencyContainer ()

@property (nonatomic, strong) id<SentryANRTracker> anrTracker;

@end

@implementation SentryDependencyContainer

static SentryDependencyContainer *instance;
static NSObject *sentryDependencyContainerLock;

+ (void)initialize
{
    if (self == [SentryDependencyContainer class]) {
        sentryDependencyContainerLock = [[NSObject alloc] init];
        instance = [[SentryDependencyContainer alloc] init];
    }
}

+ (instancetype)sharedInstance
{
    return instance;
}

+ (void)reset
{
    if (instance) {
#if SENTRY_HAS_REACHABILITY
        [instance->_reachability removeAllObservers];
#endif // !TARGET_OS_WATCH

#if SENTRY_HAS_UIKIT
        [instance->_framesTracker stop];
#endif // SENTRY_HAS_UIKIT
    }

    instance = [[SentryDependencyContainer alloc] init];
}

- (instancetype)init
{
    if (self = [super init]) {
        _dispatchQueueWrapper = [[SentryDispatchQueueWrapper alloc] init];
        _random = [[SentryRandom alloc] init];
        _threadWrapper = [[SentryThreadWrapper alloc] init];
        _binaryImageCache = [[SentryBinaryImageCache alloc] init];
        _dateProvider = [[SentryDefaultCurrentDateProvider alloc] init];
    }
    return self;
}

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

- (SentryCrashWrapper *)crashWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_crashWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_crashWrapper == nil) {
                _crashWrapper = [SentryCrashWrapper sharedInstance];
            }
        }
    }
    return _crashWrapper;
}

- (SentryCrash *)crashReporter SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_crashReporter == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_crashReporter == nil) {
                _crashReporter =
                    [[SentryCrash alloc] initWithBasePath:SentrySDK.options.cacheDirectoryPath];
            }
        }
    }
    return _crashReporter;
}

- (SentrySysctl *)sysctlWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_sysctlWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_sysctlWrapper == nil) {
                _sysctlWrapper = [[SentrySysctl alloc] init];
            }
        }
    }
    return _sysctlWrapper;
}

- (SentryThreadInspector *)threadInspector SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_threadInspector == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_threadInspector == nil) {
                _threadInspector =
                    [[SentryThreadInspector alloc] initWithOptions:SentrySDK.options];
            }
        }
    }
    return _threadInspector;
}

- (SentryFileIOTracker *)fileIOTracker SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_fileIOTracker == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_fileIOTracker == nil) {
                _fileIOTracker =
                    [[SentryFileIOTracker alloc] initWithThreadInspector:[self threadInspector]
                                                      processInfoWrapper:[self processInfoWrapper]];
            }
        }
    }
    return _fileIOTracker;
}

- (SentryDebugImageProvider *)debugImageProvider
{
    @synchronized(sentryDependencyContainerLock) {
        if (_debugImageProvider == nil) {
            _debugImageProvider = [[SentryDebugImageProvider alloc] init];
        }
        return _debugImageProvider;
    }
}

- (SentryExtraContextProvider *)extraContextProvider SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_extraContextProvider == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_extraContextProvider == nil) {
                _extraContextProvider = [[SentryExtraContextProvider alloc] init];
            }
        }
    }
    return _extraContextProvider;
}

- (SentryNSNotificationCenterWrapper *)notificationCenterWrapper
{
    @synchronized(sentryDependencyContainerLock) {
        if (_notificationCenterWrapper == nil) {
            _notificationCenterWrapper = [[SentryNSNotificationCenterWrapper alloc] init];
        }
        return _notificationCenterWrapper;
    }
}

- (id<SentryRateLimits>)rateLimits
{
    @synchronized(sentryDependencyContainerLock) {
        if (_rateLimits == nil) {
            SentryRetryAfterHeaderParser *retryAfterHeaderParser =
                [[SentryRetryAfterHeaderParser alloc]
                    initWithHttpDateParser:[[SentryHttpDateParser alloc] init]
                       currentDateProvider:self.dateProvider];
            SentryRateLimitParser *rateLimitParser =
                [[SentryRateLimitParser alloc] initWithCurrentDateProvider:self.dateProvider];

            _rateLimits = [[SentryDefaultRateLimits alloc]
                initWithRetryAfterHeaderParser:retryAfterHeaderParser
                            andRateLimitParser:rateLimitParser
                           currentDateProvider:self.dateProvider];
        }
        return _rateLimits;
    }
}

#if SENTRY_HAS_UIKIT
- (SentryUIDeviceWrapper *)uiDeviceWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_uiDeviceWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_uiDeviceWrapper == nil) {
                _uiDeviceWrapper = [[SentryUIDeviceWrapper alloc] init];
            }
        }
    }
    return _uiDeviceWrapper;
}

#endif // SENTRY_HAS_UIKIT

#if SENTRY_TARGET_REPLAY_SUPPORTED
- (SentryScreenshot *)screenshot SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
#    if SENTRY_HAS_UIKIT
    if (_screenshot == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_screenshot == nil) {
                _screenshot = [[SentryScreenshot alloc] init];
            }
        }
    }
    return _screenshot;
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
    "double-checked lock produce false alarms")
{
#    if SENTRY_HAS_UIKIT
    if (_viewHierarchy == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_viewHierarchy == nil) {
                _viewHierarchy = [[SentryViewHierarchy alloc] init];
            }
        }
    }
    return _viewHierarchy;
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.viewHierarchy only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryUIApplication *)application SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
#    if SENTRY_HAS_UIKIT
    if (_application == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_application == nil) {
                _application = [[SentryUIApplication alloc] init];
            }
        }
    }
    return _application;
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.application only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryUIViewControllerPerformanceTracker *)
    uiViewControllerPerformanceTracker SENTRY_DISABLE_THREAD_SANITIZER(
        "double-checked lock produce false alarms")
{
#    if SENTRY_HAS_UIKIT
    if (_uiViewControllerPerformanceTracker == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_uiViewControllerPerformanceTracker == nil) {
                _uiViewControllerPerformanceTracker =
                    [[SentryUIViewControllerPerformanceTracker alloc]
                             initWithTracker:SentryPerformanceTracker.shared
                        dispatchQueueWrapper:[self dispatchQueueWrapper]];
            }
        }
    }
    return _uiViewControllerPerformanceTracker;
#    else
    SENTRY_LOG_DEBUG(@"SentryDependencyContainer.uiViewControllerPerformanceTracker only works "
                     @"with UIKit enabled. Ensure you're "
                     @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentryFramesTracker *)framesTracker SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
#    if SENTRY_HAS_UIKIT
    if (_framesTracker == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_framesTracker == nil) {
                _framesTracker = [[SentryFramesTracker alloc]
                    initWithDisplayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]
                                  dateProvider:self.dateProvider
                          dispatchQueueWrapper:self.dispatchQueueWrapper
                            notificationCenter:self.notificationCenterWrapper
                     keepDelayedFramesDuration:SENTRY_AUTO_TRANSACTION_MAX_DURATION];
            }
        }
    }
    return _framesTracker;
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.framesTracker only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}

- (SentrySwizzleWrapper *)swizzleWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
#    if SENTRY_HAS_UIKIT
    if (_swizzleWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_swizzleWrapper == nil) {
                _swizzleWrapper = [[SentrySwizzleWrapper alloc] init];
            }
        }
    }
    return _swizzleWrapper;
#    else
    SENTRY_LOG_DEBUG(
        @"SentryDependencyContainer.uiDeviceWrapper only works with UIKit enabled. Ensure you're "
        @"using the right configuration of Sentry that links UIKit.");
    return nil;
#    endif // SENTRY_HAS_UIKIT
}
#endif // SENTRY_UIKIT_AVAILABLE

- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
    SENTRY_DISABLE_THREAD_SANITIZER("double-checked lock produce false alarms")
{
    if (_anrTracker == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_anrTracker == nil) {
                _anrTracker =
                    [[SentryANRTrackerV1 alloc] initWithTimeoutInterval:timeout
                                                           crashWrapper:self.crashWrapper
                                                   dispatchQueueWrapper:self.dispatchQueueWrapper
                                                          threadWrapper:self.threadWrapper];
            }
        }
    }

    return _anrTracker;
}

#if SENTRY_HAS_UIKIT
- (id<SentryANRTracker>)getANRTracker:(NSTimeInterval)timeout
                          isV2Enabled:(BOOL)isV2Enabled
    SENTRY_DISABLE_THREAD_SANITIZER("double-checked lock produce false alarms")
{
    if (isV2Enabled) {
        if (_anrTracker == nil) {
            @synchronized(sentryDependencyContainerLock) {
                if (_anrTracker == nil) {
                    _anrTracker = [[SentryANRTrackerV2 alloc]
                        initWithTimeoutInterval:timeout
                                   crashWrapper:self.crashWrapper
                           dispatchQueueWrapper:self.dispatchQueueWrapper
                                  threadWrapper:self.threadWrapper
                                  framesTracker:self.framesTracker];
                }
            }
        }

        return _anrTracker;
    } else {
        return [self getANRTracker:timeout];
    }
}
#endif // SENTRY_HAS_UIKIT

- (SentryNSProcessInfoWrapper *)processInfoWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_processInfoWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_processInfoWrapper == nil) {
                _processInfoWrapper = [[SentryNSProcessInfoWrapper alloc] init];
            }
        }
    }
    return _processInfoWrapper;
}

- (SentrySystemWrapper *)systemWrapper SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_systemWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_systemWrapper == nil) {
                _systemWrapper = [[SentrySystemWrapper alloc] init];
            }
        }
    }
    return _systemWrapper;
}

- (SentryDispatchFactory *)dispatchFactory SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_dispatchFactory == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_dispatchFactory == nil) {
                _dispatchFactory = [[SentryDispatchFactory alloc] init];
            }
        }
    }
    return _dispatchFactory;
}

- (SentryNSTimerFactory *)timerFactory SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_timerFactory == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_timerFactory == nil) {
                _timerFactory = [[SentryNSTimerFactory alloc] init];
            }
        }
    }
    return _timerFactory;
}

#if SENTRY_HAS_METRIC_KIT
- (SentryMXManager *)metricKitManager SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_metricKitManager == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_metricKitManager == nil) {
                // Disable crash diagnostics as we only use it for validation of the symbolication
                // of stacktraces, because crashes are easy to trigger for MetricKit. We don't want
                // crash reports of MetricKit in production as we have SentryCrash.
                _metricKitManager = [[SentryMXManager alloc] initWithDisableCrashDiagnostics:YES];
            }
        }
    }

    return _metricKitManager;
}

#endif // SENTRY_HAS_METRIC_KIT

#if SENTRY_HAS_REACHABILITY
- (SentryReachability *)reachability SENTRY_DISABLE_THREAD_SANITIZER(
    "double-checked lock produce false alarms")
{
    if (_reachability == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_reachability == nil) {
                _reachability = [[SentryReachability alloc] init];
            }
        }
    }
    return _reachability;
}
#endif // !TARGET_OS_WATCH

@end
