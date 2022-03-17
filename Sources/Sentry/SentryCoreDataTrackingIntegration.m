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
    if ([self shouldBeDisabled:options]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    self.tracker = [[SentryCoreDataTracker alloc] init];
    [SentryCoreDataSwizzling.sharedInstance startWithMiddleware:self.tracker];
}

- (BOOL)shouldBeDisabled:(SentryOptions *)options
{
    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable CoreData tracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return YES;
    }

    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable CoreData tracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return YES;
    }

    if (!options.isTracingEnabled) {
        [SentryLog
            logWithMessage:@"Not going to enable CoreData tracking because tracing is disabled."
                  andLevel:kSentryLevelDebug];
        return YES;
    }

    if (!options.enableCoreDataTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable CoreData tracking because enableCoreDataTracking is disabled."
                  andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return YES;
    }

    return NO;
}

- (void)uninstall
{
    [SentryCoreDataSwizzling.sharedInstance stop];
}

@end
