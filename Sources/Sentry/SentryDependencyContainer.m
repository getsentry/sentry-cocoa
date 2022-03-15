#import <Foundation/Foundation.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryCrashAdapter.h>
#import <SentryDefaultCurrentDateProvider.h>
#import <SentryDependencyContainer.h>
#import <SentryHub.h>
#import <SentrySDK+Private.h>
#import <SentrySysctl.h>
#import <SentryThreadWrapper.h>

@implementation SentryDependencyContainer

static SentryDependencyContainer *instance;

+ (instancetype)sharedInstance
{
    if (instance == nil) {
        instance = [[self alloc] init];
    }
    return instance;
}

+ (void)reset
{
    instance = nil;
}

- (SentryAppStateManager *)appStateManager
{
    if (_appStateManager == nil) {
        SentryFileManager *fileManager = [[[SentrySDK currentHub] getClient] fileManager];
        SentryOptions *options = [[[SentrySDK currentHub] getClient] options];
        _appStateManager = [[SentryAppStateManager alloc]
                initWithOptions:options
                   crashAdapter:self.crashAdapter
                    fileManager:fileManager
            currentDateProvider:[SentryDefaultCurrentDateProvider sharedInstance]
                         sysctl:[[SentrySysctl alloc] init]];
    }
    return _appStateManager;
}

- (SentryCrashAdapter *)crashAdapter
{
    if (_crashAdapter == nil) {
        _crashAdapter = [SentryCrashAdapter sharedInstance];
    }
    return _crashAdapter;
}

- (SentryThreadWrapper *)threadWrapper
{
    if (_threadWrapper == nil) {
        _threadWrapper = [[SentryThreadWrapper alloc] init];
    }
    return _threadWrapper;
}

@end
