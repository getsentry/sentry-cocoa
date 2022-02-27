#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCoreDataSwizzling.h"
#import "SentryCoreDataTracker.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"

@implementation SentryCoreDataTrackingIntegration {
    SentryCoreDataTracker *tracker;
}

- (void)installWithOptions:(SentryOptions *)options
{
    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable NetworkTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    tracker = [[SentryCoreDataTracker alloc] init];
    [SentryCoreDataSwizzling.sharedInstance startWithMiddleware:tracker];
}

- (void)uninstall
{
    [SentryCoreDataSwizzling.sharedInstance stop];
}

@end
