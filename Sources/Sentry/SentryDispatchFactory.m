#import "SentryDispatchFactory.h"
#import "SentryDispatchSourceWrapper.h"
#import "SentryInternalDefines.h"
#import "SentrySwift.h"

@implementation SentryDispatchFactory

- (SentryDispatchQueueWrapper *)createLowPriorityQueue:(NSString *)name
- (SentryDispatchQueueWrapper *)createUtilityQueue:(const char *)name
                                  relativePriority:(int)relativePriority
{
    SENTRY_CASSERT(relativePriority <= 0 && relativePriority >= QOS_MIN_RELATIVE_PRIORITY,
        @"Relative priority must be between 0 and %d", QOS_MIN_RELATIVE_PRIORITY);
    return [[SentryDispatchQueueWrapper alloc] initWithUtilityNamed:name
                                                   relativePriority:relativePriority];
}

- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                concurrentQueueName:(NSString *)queueName
                                       eventHandler:(void (^)(void))eventHandler
{
    return [[SentryDispatchSourceWrapper alloc]
        initTimerWithInterval:interval
                       leeway:leeway
                        queue:[[SentryDispatchQueueWrapper alloc]
                                  initWithConccurentUtilityNamed:queueName]
                 eventHandler:eventHandler];
}

@end
