#import "SentryLogFlushIntegration.h"
#import "SentryClient+Private.h"
#import "SentryHub.h"
#import "SentryLogC.h"
#import "SentrySDK+Private.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryLogFlushIntegration () <SentryAppStateListener>

@end

@implementation SentryLogFlushIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    [[[SentryDependencyContainer sharedInstance] appStateManager] addListener:self];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableLogs;
}

- (void)uninstall
{
    [[[SentryDependencyContainer sharedInstance] appStateManager] removeListener:self];
}

#    pragma mark - SentryAppStateListener

- (void)appStateManagerWillResignActive
{
    SentryClientInternal *client = [SentrySDKInternal.currentHub getClient];
    if (client != nil) {
        [client flushLogs];
    }
}

- (void)appStateManagerWillTerminate
{
    SentryClientInternal *client = [SentrySDKInternal.currentHub getClient];
    if (client != nil) {
        [client flushLogs];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
