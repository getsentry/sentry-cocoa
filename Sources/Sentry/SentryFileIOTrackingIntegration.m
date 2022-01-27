#import "SentryFileIOTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"

@implementation SentryFileIOTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if ([self shouldBeEnabled:options]) {
        [SentryNSDataSwizzling start];
    } else {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
    }
}

- (BOOL)shouldBeEnabled:(SentryOptions *)options
{
    if (!options.enableSwizzling) {
        [SentryLog logWithMessage:
                       @"Not going to enable FileIOTracking because enableSwizzling is disabled."
                         andLevel:kSentryLevelDebug];
        return NO;
    }

    if (!options.isTracingEnabled) {
        [SentryLog logWithMessage:@"Not going to enable FileIOTracking because tracing is disabled."
                         andLevel:kSentryLevelDebug];
        return NO;
    }

    if (!options.enableAutoPerformanceTracking) {
        [SentryLog logWithMessage:@"Not going to enable FileIOTracking because "
                                  @"enableAutoPerformanceTracking is disabled."
                         andLevel:kSentryLevelDebug];
        return NO;
    }

    if (!options.enableFileIOTracking) {
        [SentryLog
            logWithMessage:
                @"Not going to enable FileIOTracking because enableFileIOTracking is disabled."
                  andLevel:kSentryLevelDebug];
        return NO;
    }

    return YES;
}

- (void)uninstall
{
    [SentryNSDataSwizzling stop];
}

@end
