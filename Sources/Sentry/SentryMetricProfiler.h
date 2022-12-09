#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryNSProcessInfoWrapper;
@class SentrySystemWrapper;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryFootprint;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyMemoryPressure;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyPowerState;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyThermalState;
SENTRY_EXTERN NSString *const kSentryMetricProfilerSerializationKeyCPUUsageFormat;

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
                           systemWrapper:(SentrySystemWrapper *)systemWrapper;
- (void)start;
- (void)stop;

/** @return All data gathered during the profiling run. */
- (NSMutableDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
