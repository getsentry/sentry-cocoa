#import "SentryDefines.h"

@class SentryDispatchQueueWrapper;
@class SentryDispatchSourceWrapper;

NS_ASSUME_NONNULL_BEGIN

/**
 * A type of object that vends wrappers for dispatch queues and sources, which can be subclassed to
 * vend their mocked test subclasses.
 */
@interface SentryDispatchFactory : SENTRY_BASE_OBJECT

/**
 * Generate a new @c SentryDispatchQueueWrapper .
 */
- (SentryDispatchQueueWrapper *)queueWithName:(const char *)name
                                   attributes:(dispatch_queue_attr_t)attributes;

/**
 * Generate a @c dispatch_source_t by internally vending the required @c SentryDispatchQueueWrapper.
 */
- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                          queueName:(const char *)queueName
                                         attributes:(dispatch_queue_attr_t)attributes
                                       eventHandler:(void (^)(void))eventHandler;

@end

NS_ASSUME_NONNULL_END
