#import "SentryLogFlushIntegration.h"
#import "SentryClient+Private.h"
#import "SentryHub.h"
#import "SentryLogC.h"
#import "SentryNotificationNames.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogFlushIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willResignActive)
                                               name:SentryWillResignActiveNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willTerminate)
                                               name:SentryWillTerminateNotification
                                             object:nil];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableLogs;
}

- (void)uninstall
{
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:SentryWillResignActiveNotification
                                                object:nil];

    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:SentryWillTerminateNotification
                                                object:nil];
}

- (void)willResignActive
{
    SentryClientInternal *client = [SentrySDKInternal.currentHub getClient];
    if (client != nil) {
        [client flushLogs];
    }
}

- (void)willTerminate
{
    SentryClientInternal *client = [SentrySDKInternal.currentHub getClient];
    if (client != nil) {
        [client flushLogs];
    }
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
