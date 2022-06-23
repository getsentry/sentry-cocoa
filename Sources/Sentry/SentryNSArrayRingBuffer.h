#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A ring buffer backed by @c NSArray that can return an @c NSArray containing its elements in the
 * order in which they were added.
 */
@interface SentryNSArrayRingBuffer<T> : NSObject

@property (nonatomic, copy) NSArray<T> *array;

/** Initialize the ring buffer to hold a max of @c capacity elements. */
- (instancetype)initWithCapacity:(NSUInteger)capacity;

/**
 * Add an object. If there are already @c capacity objects in the backing array, overwrites the
 * oldest one to make room for this one.
 */
- (void)addObject:(T)object;

/** Reset the backing array so that all previously added objects are forgotten. */
- (void)reset;

@end

NS_ASSUME_NONNULL_END
