#import "SentryAppStartTracker.h"

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT
@interface SentryAppStartTracker (TestPrivate)

+ (void)setAppStart:(nullable NSDate *)value;

@end
#endif

NS_ASSUME_NONNULL_END
