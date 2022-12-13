#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyPowerState;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyThermalState;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyCPUUsageFormat;
NS_ASSUME_NONNULL_END

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryNSProcessInfoWrapper;
@class SentryNSTimerWrapper;
@class SentrySystemWrapper;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryPressure;

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitBytes;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitBoolean;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitMemoryPressureEnum;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitThermalStateEnum;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationUnitPercentage;

/**
 * A profiler that gathers various time-series and event-based metrics on the app process, such as
 * CPU and memory usage timeseries and thermal and memory pressure warning notifications.
 */
@interface SentryMetricProfiler : NSObject

- (instancetype)initWithProfileStartTime:(uint64_t)profileStartTime
                      processInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper
                           systemWrapper:(SentrySystemWrapper *)systemWrapper
                            timerWrapper:(SentryNSTimerWrapper *)timerWrapper;
- (void)start;
- (void)stop;

/** @return All data gathered during the profiling run. */
- (NSMutableDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END

#else

// if we don't have this declaration, we wind up with a linker error: "Undefined symbol:
// _OBJC_CLASS_$_SentryMetricProfiler" referenced from SentryProfiler. Even though both are
// completely covered by #if SENTRY_TARGET_PROFILING_SUPPORTED. Not sure what's going on there
// (armcknight 13 Dec 2022)

@interface SentryMetricProfiler : NSObject
@end

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
