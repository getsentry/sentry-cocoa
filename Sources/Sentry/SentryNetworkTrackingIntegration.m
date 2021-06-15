#import "SentryNetworkTrackingIntegration.h"
#import "SentryNetworkSwizzling.h"
#import "SentryOptions.h"

@interface
SentryNetworkTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end


@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoUIPerformanceTracking) {
        [self enableNetworkTracking];
    }
}

- (void)enableNetworkTracking
{
    [SentryNetworkSwizzling start];
}

@end
