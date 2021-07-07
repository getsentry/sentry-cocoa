#import "SentryNetworkTrackingIntegration.h"
#import "SentryNetworkSwizzling.h"
#import "SentryNetworkTracker.h"
#import "SentryOptions.h"
#import "SentryHttpInterceptor.h"

@interface
SentryNetworkTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end

@implementation SentryNetworkTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoHttpRequestTracking) {
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
