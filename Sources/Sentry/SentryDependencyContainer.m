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

+ (instancetype)sharedInstance
{
    static SentryDependencyContainer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
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
