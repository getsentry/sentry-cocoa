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
    if (![self shouldBeEnabled:@[
            [[SentryOptionWithDescription alloc]
                initWithOption:options.enableAutoPerformanceTracking
                    optionName:@"enableAutoPerformanceTracking"],
            [[SentryOptionWithDescription alloc] initWithOption:options.enableSwizzling
                                                     optionName:@"enableSwizzling"],
            [[SentryOptionWithDescription alloc] initWithOption:options.isTracingEnabled
                                                     optionName:@"isTracingEnabled"],
            [[SentryOptionWithDescription alloc] initWithOption:options.enableCoreDataTracking
                                                     optionName:@"enableCoreDataTracking"],
        ]]) {
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
