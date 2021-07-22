#import "SentryNetworkTrackingIntegration.h"
#import "SentryHttpInterceptor.h"
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
        [NSURLProtocol registerClass:[SentryHttpInterceptor class]];
    }
}

- (void)uninstall
{
    [SentryNetworkSwizzling stop];
    [NSURLProtocol unregisterClass:[SentryHttpInterceptor class]];
}

@end
