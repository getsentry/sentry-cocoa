#import <Foundation/Foundation.h>
#import <SentryCrashAdapter.h>
#import <SentryDispatchQueueWrapper.h>
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
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    SentryDispatchQueueWrapper *dispatchQueueWrapper =
        [[SentryDispatchQueueWrapper alloc] initWithName:"sentry-out-of-memory-tracker"
                                              attributes:attributes];

    self.tracker =
        [[SentryOutOfMemoryTracker alloc] initWithOptions:options
                                             crashAdapter:[[SentryCrashAdapter alloc] init]
                                     dispatchQueueWrapper:dispatchQueueWrapper];
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
