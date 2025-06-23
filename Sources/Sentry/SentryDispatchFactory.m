#import "SentryDispatchFactory.h"
#import "SentryDispatchSourceWrapper.h"
#import "SentryInternalDefines.h"
#import "SentrySwift.h"

@implementation SentryDispatchFactory

- (SentryDispatchQueueWrapper *)createUtilityQueue:(const char *)name
                                  relativePriority:(int)relativePriority
{
    SENTRY_CASSERT(relativePriority <= 0 && relativePriority >= QOS_MIN_RELATIVE_PRIORITY,
        @"Relative priority must be between 0 and %d", QOS_MIN_RELATIVE_PRIORITY);
    return [[SentryDispatchQueueWrapper alloc]
        initWithUtilityNamed:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]
            relativePriority:relativePriority];
}

- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                          queueName:(const char *)queueName
                                         attributes:(dispatch_queue_attr_t)attributes
                                       eventHandler:(void (^)(void))eventHandler
{
    dispatch_queue_t queue = dispatch_queue_create(queueName, attributes);
    return [[SentryDispatchSourceWrapper alloc]
        initTimerWithInterval:interval
                       leeway:leeway
                        queue:[[SentryDispatchQueueWrapper alloc] initWithQueue:queue]
                 eventHandler:eventHandler];
}

@end
