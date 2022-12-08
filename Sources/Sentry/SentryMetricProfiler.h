#import <Foundation/Foundation.h>

@class SentryNSProcessInfoWrapper;
@class SentrySystemWrapper;

NS_ASSUME_NONNULL_BEGIN

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
