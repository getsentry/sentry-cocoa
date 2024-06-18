#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryLogSinkNSLog;

@interface
SentryLog (TestInit)

/** Internal and only needed for testing. */
+ (void)setLogOutput:(nullable SentryLogSinkNSLog *)output;

/** Internal and only needed for testing. */
+ (SentryLogSinkNSLog *)logOutput;

/** Internal and only needed for testing. */
+ (BOOL)isDebug;

/** Internal and only needed for testing. */
+ (SentryLevel)diagnosticLevel;

@end

NS_ASSUME_NONNULL_END
