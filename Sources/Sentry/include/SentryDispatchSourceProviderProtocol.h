#import <Foundation/Foundation.h>

@class SentryDispatchSourceWrapper;

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDispatchSourceProviderProtocol <NSObject>

/**
 * Generate a @c dispatch_source_t by internally vending the required @c SentryDispatchQueueWrapper.
 */
- (SentryDispatchSourceWrapper *)sourceWithInterval:(uint64_t)interval
                                             leeway:(uint64_t)leeway
                                concurrentQueueName:(NSString *)queueName
                                       eventHandler:(void (^)(void))eventHandler;
@end

NS_ASSUME_NONNULL_END
