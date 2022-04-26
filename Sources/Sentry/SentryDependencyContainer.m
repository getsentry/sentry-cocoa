#import "SentryUIApplication.h"
#import <Foundation/Foundation.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashWrapper.h>
#import <SentryDebugImageProvider.h>
#import <SentryDefaultCurrentDateProvider.h>
#import <SentryDependencyContainer.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryHub.h>
#import <SentrySDK+Private.h>
#import <SentryScreenshot.h>
#import <SentrySwizzleWrapper.h>
#import <SentrySysctl.h>
#import <SentryThreadWrapper.h>

@implementation SentryDependencyContainer

static SentryDependencyContainer *instance;
static NSObject *sentryDependencyContainerLock;

+ (void)initialize
{
    if (self == [SentryDependencyContainer class]) {
        sentryDependencyContainerLock = [[NSObject alloc] init];
    }
}

+ (instancetype)sharedInstance
{
    @synchronized(sentryDependencyContainerLock) {
        if (instance == nil) {
            instance = [[self alloc] init];
        }
        return instance;
    }
}

+ (void)reset
{
    @synchronized(sentryDependencyContainerLock) {
        instance = nil;
    }
}

- (SentryAppStateManager *)appStateManager
{
    @synchronized(sentryDependencyContainerLock) {
        if (_appStateManager == nil) {
            SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
            SentryOptions *options = [[[SentrySDK currentHub] getClient] options];
            _appStateManager = [[SentryAppStateManager alloc]
                    initWithOptions:options
                       crashWrapper:self.crashWrapper
                        fileManager:fileManager
                currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                             sysctl:[[SentrySysctl alloc] init]];
        }
        return _appStateManager;
    }
}

- (SentryCrashWrapper *)crashWrapper
{
    @synchronized(sentryDependencyContainerLock) {
        if (_crashWrapper == nil) {
            _crashWrapper = [SentryCrashWrapper sharedInstance];
        }
        return _crashWrapper;
    }
}

- (SentryThreadWrapper *)threadWrapper
{
    @synchronized(sentryDependencyContainerLock) {
        if (_threadWrapper == nil) {
            _threadWrapper = [[SentryThreadWrapper alloc] init];
        }
        return _threadWrapper;
    }
}

- (SentryDispatchQueueWrapper *)dispatchQueueWrapper
{
    @synchronized(sentryDependencyContainerLock) {
        if (_dispatchQueueWrapper == nil) {
            _dispatchQueueWrapper = [[SentryDispatchQueueWrapper alloc] init];
        }
        return _dispatchQueueWrapper;
    }
}

- (id<SentryRandom>)random
{
    @synchronized(sentryDependencyContainerLock) {
        if (_random == nil) {
            _random = [[SentryRandom alloc] init];
        }
        return _random;
    }
}

#if SENTRY_HAS_UIKIT
- (SentryScreenshot *)screenshot
{
    @synchronized(sentryDependencyContainerLock) {
        if (_screenshot == nil) {
            _screenshot = [[SentryScreenshot alloc] init];
        }
        return _screenshot;
    }
}

- (SentryUIApplication *)application
{
    @synchronized(sentryDependencyContainerLock) {
        if (_application == nil) {
            _application = [[SentryUIApplication alloc] init];
        }
    }
    return _application;
}
#endif

- (SentrySwizzleWrapper *)swizzleWrapper
{
    @synchronized(sentryDependencyContainerLock) {
        if (_swizzleWrapper == nil) {
            _swizzleWrapper = SentrySwizzleWrapper.sharedInstance;
        }
        return _swizzleWrapper;
    }
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

@end
