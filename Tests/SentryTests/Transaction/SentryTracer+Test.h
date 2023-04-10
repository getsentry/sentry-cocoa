#import "SentryProfilingConditionals.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTracer (Test)

+ (void)resetAppStartMeasurementRead;

- (void)updateStartTime:(NSDate *)startTime;

#if SENTRY_TARGET_PROFILING_SUPPORTED
+ (void)resetConcurrencyTracking;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END
