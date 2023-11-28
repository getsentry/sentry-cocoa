#import "SentryDispatchFactory.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDispatchSourceWrapper.h"

@implementation SentryDispatchFactory

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (SentryDispatchQueueWrapper *)queueWithName:(const char *)name
                                   attributes:(dispatch_queue_attr_t)attributes
{
    return [[SentryDispatchQueueWrapper alloc] initWithName:name attributes:attributes];
}

- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                          queueName:(const char *)queueName
                                         attributes:(dispatch_queue_attr_t)attributes
                                       eventHandler:(void (^)(void))eventHandler
{
    return [[SentryDispatchSourceWrapper alloc]
        initTimerWithInterval:interval
                       leeway:leeway
                        queue:[self queueWithName:queueName attributes:attributes]
                 eventHandler:eventHandler];
}

@end
