#import <Foundation/Foundation.h>
#import <SentryCrashAdapter.h>
#import <SentryOutOfMemoryTracker.h>
#import <SentryOutOfMemoryTrackingIntegration.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryOutOfMemoryTrackingIntegration ()

@property (nonatomic, strong) SentryOutOfMemoryTracker *tracker;

@end

@implementation SentryOutOfMemoryTrackingIntegration

- (void)installWithOptions:(SentryOptions *)options
{
    self.tracker =
        [[SentryOutOfMemoryTracker alloc] initWithOptions:options
                                             crashAdapter:[[SentryCrashAdapter alloc] init]];
    [self.tracker start];
}

- (void)stop
{
    if (nil != self.tracker) {
        [self.tracker stop];
    }
}

@end

NS_ASSUME_NONNULL_END
