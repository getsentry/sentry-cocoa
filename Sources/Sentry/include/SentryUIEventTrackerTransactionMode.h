#import "SentryUIEventTrackerMode.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryUIEventTrackerTransactionMode : SENTRY_BASE_OBJECT <SentryUIEventTrackerMode>
SENTRY_NO_INIT

- (instancetype)initWithIdleTimeout:(NSTimeInterval)idleTimeout;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
