#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

@class SentrySwizzleWrapper, SentryDispatchQueueWrapper;

@interface SentryUIEventTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
                  dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (void)start;
- (void)stop;

+ (BOOL)isUIEventOperation:(NSString *)operation;

@end

#endif

NS_ASSUME_NONNULL_END
