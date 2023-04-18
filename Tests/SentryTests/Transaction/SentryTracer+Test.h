#import "SentryProfilingConditionals.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTracer (Test)

+ (void)resetAppStartMeasurementRead;

- (void)updateStartTime:(NSDate *)startTime;

#if SENTRY_TARGET_PROFILING_SUPPORTED && (defined(TEST) || defined(TESTCI))
+ (void)resetConcurrencyTracking;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED && (defined(TEST) || defined(TESTCI))

@end

NS_ASSUME_NONNULL_END
