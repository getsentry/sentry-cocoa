#import "SentryDispatchQueueProvider.h"

@implementation SentryDispatchQueueProvider

- (SentryDispatchQueueWrapper *)createBackgroundQueueWithName:(const char *)name
                                             relativePriority:(int)relativePriority
{
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, relativePriority);
    return [[SentryDispatchQueueWrapper alloc] initWithName:name attributes:attributes];
}

@end
