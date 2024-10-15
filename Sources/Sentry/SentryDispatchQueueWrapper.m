#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"
#import "SentryThreadWrapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDispatchQueueWrapper ()

@property (nonatomic, assign) BOOL callingThread;

@end

@implementation SentryDispatchQueueWrapper

- (instancetype)init
{
    // DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL is requires iOS 10. Since we are targeting
    // iOS 9 we need to manually add the autoreleasepool.
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self = [self initWithName:"sentry-default" attributes:attributes];
    return self;
}

- (instancetype)initWithName:(const char *)name
                  attributes:(nullable dispatch_queue_attr_t)attributes;
{
    if (self = [super init]) {
        _queue = dispatch_queue_create(name, attributes);
        _callingThread = NO;
    }
    return self;
}

- (void)dispatchAllOnCallingThread
{
    SENTRY_LOG_DEBUG(@"dispatchAllOnCallingThread: YES");
    _callingThread = YES;
}

- (void)dispatchAsyncWithBlock:(void (^)(void))block
{
    if (self.callingThread == YES) {
        SENTRY_LOG_DEBUG(@"CallingThread: Yes");
        block();
        return;
    }

    dispatch_async(_queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchAsyncOnMainQueue:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                block();
            }
        });
    }
}

- (void)dispatchSync:(void (^)(void))block
{
    dispatch_sync(_queue, block);
}

- (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

- (BOOL)dispatchSyncOnMainQueue:(void (^)(void))block timeout:(NSTimeInterval)timeout
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        dispatch_async(dispatch_get_main_queue(), ^{
            block();
            dispatch_semaphore_signal(semaphore);
        });

        dispatch_time_t timeout_t
            = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC));
        return dispatch_semaphore_wait(semaphore, timeout_t) == 0;
    }
    return YES;
}

- (void)dispatchAfter:(NSTimeInterval)interval block:(dispatch_block_t)block
{
    dispatch_time_t delta = (int64_t)(interval * NSEC_PER_SEC);
    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, delta);
    dispatch_after(when, _queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (void)dispatchCancel:(dispatch_block_t)block
{
    dispatch_block_cancel(block);
}

- (void)dispatchOnce:(dispatch_once_t *)predicate block:(void (^)(void))block
{
    dispatch_once(predicate, block);
}

- (nullable dispatch_block_t)createDispatchBlock:(void (^)(void))block
{
    return dispatch_block_create(0, block);
}

@end

NS_ASSUME_NONNULL_END
