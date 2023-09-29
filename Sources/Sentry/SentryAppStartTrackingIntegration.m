#import "SentryAppStartTrackingIntegration.h"

#if UIKIT_LINKED

#    import "SentryAppStartTracker.h"
#    import "SentryLog.h"
#    import <Foundation/Foundation.h>
#    import <PrivateSentrySDKOnly.h>
#    import <SentryAppStateManager.h>
#    import <SentryCrashWrapper.h>
#    import <SentryDependencyContainer.h>
#    import <SentryDispatchQueueWrapper.h>

@interface
SentryAppStartTrackingIntegration ()

@property (nonatomic, strong) SentryAppStartTracker *tracker;

@end

@implementation SentryAppStartTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (!PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode
        && ![super installWithOptions:options]) {
        return NO;
    }

    SentryAppStateManager *appStateManager =
        [SentryDependencyContainer sharedInstance].appStateManager;

    self.tracker = [[SentryAppStartTracker alloc]
          initWithDispatchQueueWrapper:[[SentryDispatchQueueWrapper alloc] init]
                       appStateManager:appStateManager
        enablePreWarmedAppStartTracing:options.enablePreWarmedAppStartTracing];
    [self.tracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionIsTracingEnabled;
}

- (void)uninstall
{
    [self stop];
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

#endif // UIKIT_LINKED
