#import "SentryPerformanceTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryUIViewControllerSwizziling.h"

@interface
SentryPerformanceTrackingIntegration ()

@property (nonatomic, strong) SentryOptions *options;
@end

@implementation SentryPerformanceTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.options = options;
    if (options.enableAutoPerformanceTracking) {
        [self enableUIAutomaticPerformanceTracking];
    }
}

- (void)enableUIAutomaticPerformanceTracking
{
#if SENTRY_HAS_UIKIT
    [SentryUIViewControllerSwizziling start];
#else
    [SentryLog logWithMessage:@"NO UIKit -> [SentryPerformanceTrackingIntegration "
                              @"start] does nothing."
                     andLevel:kSentryLevelDebug];
#endif
}

@end
