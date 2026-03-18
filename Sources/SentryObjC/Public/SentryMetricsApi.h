#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryAttributeContent;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for recording metrics (counters, distributions, and gauges) in Sentry.
 *
 * This protocol provides an API for recording telemetry metrics that can be used
 * for monitoring application performance, tracking business metrics, and analyzing system behavior.
 *
 * Access via @c [SentrySDK metrics].
 *
 * @see SentryAttributeContent
 * @see SentryUnit.h for predefined unit constants
 */
@protocol SentryMetricsApi <NSObject>

/**
 * Records a count metric for the specified key.
 *
 * Use this to increment or set a discrete occurrence count associated with a metric key,
 * such as the number of events, requests, or errors.
 *
 * @param key A namespaced identifier for the metric (e.g., @c "network.request.count").
 *            Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
 * @param value The count value to record. A non-negative integer (e.g., 1 to increment by one).
 * @param attributes Optional dictionary of attributes to attach to the metric.
 *                   Keys are strings, values are @c SentryAttributeContent instances.
 *                   Pass @c nil or empty dictionary if no attributes are needed.
 *
 * @code
 * [[SentrySDK metrics] countWithKey:@"button.click"
 *                                  value:1
 *                             attributes:@{
 *     @"screen": [SentryAttributeContent stringWithValue:@"home"]
 * }];
 * @endcode
 */
- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value
          attributes:(nullable NSDictionary<NSString *, SentryAttributeContent *> *)attributes;

/**
 * Records a distribution metric for the specified key.
 *
 * Use this to track the distribution of a value over time, such as response times,
 * request durations, or any measurable quantity where you want to analyze statistical
 * properties (mean, median, percentiles, etc.).
 *
 * @param key A namespaced identifier for the metric (e.g., @c "http.request.duration").
 *            Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
 * @param value The value to record in the distribution. This can be any numeric value
 *              representing the measurement (e.g., milliseconds for response time).
 * @param unit Optional unit of measurement (e.g., @c SentryUnitNameMillisecond).
 *             Use constants from @c SentryUnit.h or create custom units via @c
 * SentryUnitWithName(). Pass @c nil if no unit is needed.
 * @param attributes Optional dictionary of attributes to attach to the metric.
 *                   Pass @c nil or empty dictionary if no attributes are needed.
 *
 * @code
 * [[SentrySDK metrics] distributionWithKey:@"response.time"
 *                                         value:125.5
 *                                          unit:SentryUnitNameMillisecond
 *                                    attributes:@{
 *     @"endpoint": [SentryAttributeContent stringWithValue:@"/api/data"]
 * }];
 * @endcode
 */
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable NSString *)unit
                 attributes:
                     (nullable NSDictionary<NSString *, SentryAttributeContent *> *)attributes;

/**
 * Records a gauge metric for the specified key.
 *
 * Use this to track a value that can go up and down over time, such as current memory usage,
 * queue depth, active connections, or any metric that represents a current state rather
 * than an incrementing counter.
 *
 * @param key A namespaced identifier for the metric (e.g., @c "memory.usage", @c "queue.depth").
 *            Prefer stable, lowercase, dot-delimited names to aid aggregation and filtering.
 * @param value The current gauge value to record. This represents the state at the time of
 *              recording (e.g., current memory in bytes, current number of items in queue).
 * @param unit Optional unit of measurement (e.g., @c SentryUnitNameByte).
 *             Use constants from @c SentryUnit.h or create custom units via @c
 * SentryUnitWithName(). Pass @c nil if no unit is needed.
 * @param attributes Optional dictionary of attributes to attach to the metric.
 *                   Pass @c nil or empty dictionary if no attributes are needed.
 *
 * @code
 * [[SentrySDK metrics] gaugeWithKey:@"queue.depth"
 *                                  value:42
 *                                   unit:SentryUnitWithName(@"items")
 *                             attributes:@{
 *     @"queue": [SentryAttributeContent stringWithValue:@"upload"]
 * }];
 * @endcode
 */
- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable NSString *)unit
          attributes:(nullable NSDictionary<NSString *, SentryAttributeContent *> *)attributes;

@end

NS_ASSUME_NONNULL_END
