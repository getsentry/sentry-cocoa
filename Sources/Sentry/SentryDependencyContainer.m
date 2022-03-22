#import <Foundation/Foundation.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashWrapper.h>
#import <SentryDefaultCurrentDateProvider.h>
#import <SentryDependencyContainer.h>
#import <SentryHub.h>
#import <SentrySDK+Private.h>
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

- (id<SentryRandom>)random
{
    @synchronized(sentryDependencyContainerLock) {
        if (_random == nil) {
            _random = [[SentryRandom alloc] init];
        }
        return _random;
    }
}

@end
