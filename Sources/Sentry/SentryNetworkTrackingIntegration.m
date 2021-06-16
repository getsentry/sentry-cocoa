#import "SentryNetworkTrackingIntegration.h"
#import "SentryNetworkSwizzling.h"
#import "SentryOptions.h"
#import "SentryNetworkTracker.h"

@interface
SentryNetworkTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end


@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoUIPerformanceTracking) {
        [self enableNetworkTracking:[NSURL URLWithString:options.dsn]];
        
    }
}

- (void)enableNetworkTracking:(NSURL *)sentryApiUrl
{
    [SentryNetworkTracker.sharedInstance setSentryApiUrl:sentryApiUrl];
    [SentryNetworkSwizzling start];
}

@end
