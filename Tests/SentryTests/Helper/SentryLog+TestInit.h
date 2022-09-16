#import "SentryLog.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryLogOutput;

@interface
SentryLog (TestInit)

/** Internal and only needed for testing. */
+ (void)setLogOutput:(nullable SentryLogOutput *)output;

/** Internal and only needed for testing. */
+ (SentryLogOutput *)logOutput;

/** Internal and only needed for testing. */
+ (BOOL)isDebug;

/** Internal and only needed for testing. */
+ (SentryLevel)diagnosticLevel;

@end

NS_ASSUME_NONNULL_END
