#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySwizzleWrapper, SentryDispatchQueueWrapper;

@interface SentryUIEventTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
                  dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
