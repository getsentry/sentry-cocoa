#import "SentryPerformanceTrackingIntegration.h"
#import "SentryUIPerformanceTracker.h"
#import "SentryURLProtocolTracker.h"

@interface
SentryPerformanceTrackingIntegration ()

@property (nonatomic, weak) SentryOptions *options;
@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;
    [self enableURLIntercepting];
    [self enableUIAutomaticPerformanceTracking];
}

- (void)enableURLIntercepting
{
    [NSURLProtocol registerClass:SentryURLProtocolTracker.class];
}

- (void)enableUIAutomaticPerformanceTracking
{
    [SentryUIPerformanceTracker start];
}

@end
