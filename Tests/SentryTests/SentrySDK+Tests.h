#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Tests)

+ (void)setCurrentHub:(SentryHub *)hub;

@end

NS_ASSUME_NONNULL_END
