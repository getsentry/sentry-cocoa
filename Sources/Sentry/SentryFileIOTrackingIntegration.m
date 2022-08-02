#import "SentryFileIOTrackingIntegration.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"

@implementation SentryFileIOTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    if (![self shouldBeEnabled:@[
            [[SentryOptionWithDescription alloc] initWithOption:options.enableSwizzling
                                                     optionName:@"enableSwizzling"],
            [[SentryOptionWithDescription alloc] initWithOption:options.isTracingEnabled
                                                     optionName:@"isTracingEnabled"],
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableAutoPerformanceTracking
                    optionName:@"enableAutoPerformanceTracking"],
            [[SentryOptionWithDescription alloc] initWithOption:options.enableFileIOTracking
                                                     optionName:@"enableFileIOTracking"],
        ]]) {
        [options removeEnabledIntegration:NSStringFromClass([self class])];
        return;
    }

    [SentryNSDataSwizzling start];
}

- (void)uninstall
{
    [SentryNSDataSwizzling stop];
}

@end
