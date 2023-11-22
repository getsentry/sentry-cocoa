#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryLogOutput : SENTRY_BASE_OBJECT

- (void)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
