#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// dispatch_block_t is not compatible with Swift, this wraps it
// so we can pass dispatch blocks through the Swift interface.
@interface SentryDispatchBlockWrapper : NSObject

@property dispatch_block_t block;

@end

/**
 * A wrapper around DispatchQueue functions for testability.
 * This should not be used directly, instead the  Swift version in
 * SentryDispatchQueueWrapper should be used to ensure compatibility
 * with Swift code.
 */
@interface _SentryDispatchQueueWrapperInternal : NSObject

@property (strong, nonatomic) dispatch_queue_t queue;

- (instancetype)initWithName:(const char *)name
                  attributes:(nullable dispatch_queue_attr_t)attributes;

- (void)dispatchAsyncWithBlock:(void (^)(void))block;

- (void)dispatchSync:(void (^)(void))block;

- (void)dispatchAsyncOnMainQueue:(void (^)(void))block
    NS_SWIFT_NAME(dispatchAsyncOnMainQueue(block:));

- (void)dispatchSyncOnMainQueue:(void (^)(void))block
    NS_SWIFT_NAME(dispatchSyncOnMainQueue(block:));

- (BOOL)dispatchSyncOnMainQueue:(void (^)(void))block timeout:(NSTimeInterval)timeout;

- (void)dispatchAfter:(NSTimeInterval)interval block:(SentryDispatchBlockWrapper *)block;

- (void)dispatchCancel:(SentryDispatchBlockWrapper *)block;

- (void)dispatchOnce:(dispatch_once_t *)predicate block:(void (^)(void))block;

- (nullable SentryDispatchBlockWrapper *)createDispatchBlock:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
