#import "SentryAppStartTrackingIntegration.h"

#if SENTRY_HAS_UIKIT

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

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

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
                         framesTracker:SentryDependencyContainer.sharedInstance.framesTracker
        enablePreWarmedAppStartTracing:options.enablePreWarmedAppStartTracing
                   enablePerformanceV2:options.enablePerformanceV2];
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

#endif // SENTRY_HAS_UIKIT
