#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCoreDataSwizzling.h"
#import "SentryCoreDataTracker.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"

@interface
SentryCoreDataTrackingIntegration ()

@property (nonatomic, strong) SentryCoreDataTracker *tracker;

@end

@implementation SentryCoreDataTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable NetworkTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    if (!options.enableCoreDataTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable NetworkTracking because enableCoreDataTracking is disabled."
                  andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.tracker = [[SentryCoreDataTracker alloc] init];
    [SentryCoreDataSwizzling.sharedInstance startWithMiddleware:self.tracker];
}

- (void)uninstall
{
    [SentryCoreDataSwizzling.sharedInstance stop];
}

@end
