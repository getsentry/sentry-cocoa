#import <Sentry/Sentry.h>
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryLogOutput;

@interface SentryLog (TestInit)

+ (void)setLogOutput:(nullable SentryLogOutput *)output;

@end

NS_ASSUME_NONNULL_END
