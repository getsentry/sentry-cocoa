#import "SentryDispatchQueueWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SentryDispatchQueueProviderProtocol <NSObject>

/**
 * Creates a background queue with the given name and relative priority.
 *
 * @note This method is only a factory method and does not keep a reference to the created queue.
 *
 * @param name The name of the queue.
 * @param relativePriority The priority of the queue relative to the background QoS.
 * @return Unretained reference to the created queue.
 */
- (SentryDispatchQueueWrapper *)createBackgroundQueueWithName:(const char *)name
                                             relativePriority:(int)relativePriority;

@end

NS_ASSUME_NONNULL_END
