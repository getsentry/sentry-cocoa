#import "SentryNetworkTrackingIntegration.h"
#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions.h"

@interface
SentryNetworkTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end

@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoPerformanceTracking) {
        [SentryNetworkSwizzling start];
    }
}

- (void)uninstall
{
    [SentryNetworkSwizzling stop];
}

@end
