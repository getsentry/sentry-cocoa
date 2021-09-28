#import "SentryNetworkTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions.h"

@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    // We don't check isTracingEnabled, because the integration
    // also creates breadcrumbs for HTTP requests.
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable NetworkTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableNetworkTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable NetworkTracking because enableNetworkTracking is disabled."
                  andLevel:kSentryLevelDebug];
        return;
    }

    [SentryNetworkSwizzling start];
}

- (void)uninstall
{
    [SentryNetworkSwizzling stop];
}

@end
