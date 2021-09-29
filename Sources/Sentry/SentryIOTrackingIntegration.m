#import "SentryIOTrackingIntegration.h"
#import "SentryOptions.h"
#import "SentryNSDataSwizzling.h"

@interface
SentryIOTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end


@implementation SentryIOTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoPerformanceTracking) {
        [SentryNSDataSwizzling start];
    }
}

- (void)uninstall
{
    [SentryNSDataSwizzling stop];
}

@end
