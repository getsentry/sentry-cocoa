#import "SentryIOTrackingIntegration.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions.h"

@interface
SentryIOTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end

@implementation SentryIOTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableSwizzling && options.enableAutoPerformanceTracking
        && options.enableIOTracking) {
        [SentryNSDataSwizzling start];
    }
}

- (void)uninstall
{
    [SentryNSDataSwizzling stop];
}

@end
