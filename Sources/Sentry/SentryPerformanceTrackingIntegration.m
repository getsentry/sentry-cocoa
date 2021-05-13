#import "SentryPerformanceTrackingIntegration.h"
#import "SentryUIPerformanceTracker.h"

@interface
SentryPerformanceTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoUIPerformanceTracking) {
        [self enableUIAutomaticPerformanceTracking];
    }
}

- (void)enableUIAutomaticPerformanceTracking
{
    [SentryUIPerformanceTracker start];
}

@end
