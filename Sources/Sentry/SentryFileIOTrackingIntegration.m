#import "SentryFileIOTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions.h"

@implementation SentryFileIOTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable FileIOTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:@"Not going to enable FileIOTracking because tracing is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable FileIOTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return;
    }

    if (!options.enableFileIOTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable FileIOTracking because enableFileIOTracking is disabled."
                  andLevel:kSentryLevelDebug];
        return;
    }

    self.isEnabled = YES;
    [SentryNSDataSwizzling start];
}

- (void)uninstall
{
    self.isEnabled = NO;
    [SentryNSDataSwizzling stop];
}

@end
