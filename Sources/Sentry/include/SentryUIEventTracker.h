#import "SentryDefines.h"

#if UIKIT_LINKED

NS_ASSUME_NONNULL_BEGIN

@class SentryDispatchQueueWrapper;

@interface SentryUIEventTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                                 idleTimeout:(NSTimeInterval)idleTimeout;

- (void)start;
- (void)stop;

+ (BOOL)isUIEventOperation:(NSString *)operation;

@end

NS_ASSUME_NONNULL_END

#endif // UIKIT_LINKED
