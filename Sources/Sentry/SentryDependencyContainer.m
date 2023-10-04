#import "SentryANRTracker.h"
#import "SentryBinaryImageCache.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDispatchFactory.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDisplayLinkWrapper.h"
#import "SentryExtraContextProvider.h"
#import "SentryNSProcessInfoWrapper.h"
#import "SentryNSTimerFactory.h"
#import "SentryRandom.h"
#import "SentrySysctl.h"
#import "SentrySystemWrapper.h"
#import "SentryUIDeviceWrapper.h"
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashWrapper.h>
#import <SentryDebugImageProvider.h>
#import <SentryDependencyContainer.h>
#import <SentryHub.h>
#import <SentryNSNotificationCenterWrapper.h>
#import <SentrySDK+Private.h>
#import <SentrySwift.h>
#import <SentrySwizzleWrapper.h>
#import <SentrySysctl.h>
#import <SentryThreadWrapper.h>

#if SENTRY_HAS_UIKIT
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
    instance = [[SentryDependencyContainer alloc] init];
}

- (instancetype)init
{
    if (self = [super init]) {
        _dispatchQueueWrapper = [[SentryDispatchQueueWrapper alloc] init];
        _random = [[SentryRandom alloc] init];
        _threadWrapper = [[SentryThreadWrapper alloc] init];
        _binaryImageCache = [[SentryBinaryImageCache alloc] init];
        _debugImageProvider = [[SentryDebugImageProvider alloc] init];
        _dateProvider = [[SentryCurrentDateProvider alloc] init];
    }
    return self;
}

- (SentryFileManager *)fileManager
{
    @synchronized(sentryDependencyContainerLock) {
        if (_fileManager == nil) {
            _fileManager = [[[SentrySDK currentHub] getClient] fileManager];
        }
        return _fileManager;
    }
}

- (SentryAppStateManager *)appStateManager
{
    @synchronized(sentryDependencyContainerLock) {
        if (_appStateManager == nil) {
            SentryOptions *options = [[[SentrySDK currentHub] getClient] options];
            _appStateManager =
                [[SentryAppStateManager alloc] initWithOptions:options
                                                  crashWrapper:self.crashWrapper
                                                   fileManager:self.fileManager
                                          dispatchQueueWrapper:self.dispatchQueueWrapper
                                     notificationCenterWrapper:self.notificationCenterWrapper];
        }
        return _appStateManager;
    }
}

- (SentryCrashWrapper *)crashWrapper
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

- (SentrySysctl *)sysctlWrapper
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

- (SentryExtraContextProvider *)extraContextProvider
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

#if TARGET_OS_IOS
- (SentryUIDeviceWrapper *)uiDeviceWrapper
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
#endif // TARGET_OS_IOS

#if SENTRY_HAS_UIKIT
- (SentryScreenshot *)screenshot
{
    if (_screenshot == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_screenshot == nil) {
                _screenshot = [[SentryScreenshot alloc] init];
            }
        }
    }
    return _screenshot;
}

- (SentryViewHierarchy *)viewHierarchy
{
    if (_viewHierarchy == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_viewHierarchy == nil) {
                _viewHierarchy = [[SentryViewHierarchy alloc] init];
            }
        }
    }
    return _viewHierarchy;
}

- (SentryUIApplication *)application
{
    if (_application == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_application == nil) {
                _application = [[SentryUIApplication alloc] init];
            }
        }
    }
    return _application;
}

- (SentryFramesTracker *)framesTracker
{
    if (_framesTracker == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_framesTracker == nil) {
                _framesTracker = [[SentryFramesTracker alloc]
                    initWithDisplayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]];
            }
        }
    }
    return _framesTracker;
}
#endif // SENTRY_HAS_UIKIT

- (SentrySwizzleWrapper *)swizzleWrapper
{
    if (_swizzleWrapper == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_swizzleWrapper == nil) {
                _swizzleWrapper = [[SentrySwizzleWrapper alloc] init];
            }
        }
    }
    return _swizzleWrapper;
}

- (SentryANRTracker *)getANRTracker:(NSTimeInterval)timeout
{
    if (_anrTracker == nil) {
        @synchronized(sentryDependencyContainerLock) {
            if (_anrTracker == nil) {
                _anrTracker =
                    [[SentryANRTracker alloc] initWithTimeoutInterval:timeout
                                                         crashWrapper:self.crashWrapper
                                                 dispatchQueueWrapper:self.dispatchQueueWrapper
                                                        threadWrapper:self.threadWrapper];
            }
        }
    }

    return _anrTracker;
}

- (SentryNSProcessInfoWrapper *)processInfoWrapper
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

- (SentrySystemWrapper *)systemWrapper
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

- (SentryDispatchFactory *)dispatchFactory
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

- (SentryNSTimerFactory *)timerFactory
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
- (SentryMXManager *)metricKitManager
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

#if !TARGET_OS_WATCH
- (SentryReachability *)reachability
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
