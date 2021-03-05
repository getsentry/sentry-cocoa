#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryLog (TestInit)

+ (void)setLogOutput:(nullable SentryLogOutput *)output;

@end

NS_ASSUME_NONNULL_END
