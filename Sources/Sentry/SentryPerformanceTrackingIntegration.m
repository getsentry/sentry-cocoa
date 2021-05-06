#import "SentryPerformanceTrackingIntegration.h"
#import "SentryUIPerformanceTracker.h"

@interface
SentryPerformanceTrackingIntegration ()

@property (nonatomic, weak) SentryOptions *options;
@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;
    [self enableUIAutomaticPerformanceTracking];
}

- (void)enableUIAutomaticPerformanceTracking
{
    [SentryUIPerformanceTracker start];
}

@end
