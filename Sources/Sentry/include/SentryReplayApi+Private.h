#import "SentryReplayApi.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

@class _SentryDispatchQueueWrapperInternal;

NS_ASSUME_NONNULL_BEGIN

@interface SentryReplayApi (Private)

/**
 * Internal initializer for dependency injection.
 * This method is only available for internal SDK use.
 */
- (instancetype)initPrivateWithDispatchQueueWrapper:
    (_SentryDispatchQueueWrapperInternal *)dispatchQueueWrapper;

@end

NS_ASSUME_NONNULL_END

#endif
