#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around sysctl for testability.
 */
@interface SentrySysctl : SENTRY_BASE_OBJECT

/**
 * Returns the time the system was booted with a precision of microseconds.
 */
@property (readonly) NSDate *systemBootTimestamp;

@property (readonly) NSDate *processStartTimestamp;

@property (readonly) NSDate *runtimeInitTimestamp;

@property (readonly) NSDate *moduleInitializationTimestamp;

@end

NS_ASSUME_NONNULL_END
