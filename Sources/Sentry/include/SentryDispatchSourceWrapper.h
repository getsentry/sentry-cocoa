#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDispatchSourceWrapper : NSObject

- (instancetype)initWithDispatchSource:(dispatch_source_t)source;

- (void)resumeWithHandler:(dispatch_block_t)handler;

- (uintptr_t)getData;

- (void)invalidate;

@end

@interface SentryDispatchSourceFactory : NSObject

- (SentryDispatchSourceWrapper *)dispatchSourceWithType:(dispatch_source_type_t)type
                                                 handle:(uintptr_t)handle
                                                   mask:(uintptr_t)mask
                                                  queue:(dispatch_queue_t _Nullable)sourceQueue;

@end

NS_ASSUME_NONNULL_END
