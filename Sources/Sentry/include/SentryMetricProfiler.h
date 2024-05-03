#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import "SentryProfilerDefines.h"
#    import <Foundation/Foundation.h>

@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

/**
 * A profiler that gathers various time-series and event-based metrics on the app process, such as
 * CPU and memory usage timeseries and thermal and memory pressure warning notifications.
 */
@interface SentryMetricProfiler : NSObject

- (instancetype)initWithMode:(SentryProfilerMode)mode;
SENTRY_NO_INIT

- (void)start;
/** Record a metrics sample. Helps ensure full metric coverage for concurrent spans. */
- (void)recordMetrics;
- (void)stop;

/**
 * Return a serialized dictionary of the collected metrics.
 * @discussion The dictionary will have the following structure:
 * @code
 * @"<metric-name>": @{
 *      @"unit": @"<unit-name>",
 *      @"values": @[
 *          @{
 *              @"elapsed_since_start_ns": @"<64-bit-unsigned-timestamp>",
 *              @"value": @"<numeric-value>"
 *          },
 *          // ... more dictionaries like that ...
 *      ]
 * }
 * @endcode
 * @note Continuous profiling will use millisecond resolution for timestamps, and hence also will
 * not need to store them as @c NSString, but rather as @c NSNumber . It will be stored under the
 * key @c "timestamp" .
 */
- (NSMutableDictionary<NSString *, SentrySerializedMetricEntry *> *)
    serializeBetween:(uint64_t)startSystemTime
                 and:(uint64_t)endSystemTime;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
