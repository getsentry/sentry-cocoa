#import <Foundation/Foundation.h>

@class SentryObjCAttributeContent;
@class SentryObjCUnit;

NS_ASSUME_NONNULL_BEGIN

/**
 * API for recording metrics (counters, distributions, and gauges) in Sentry.
 *
 * Provides a type-safe API for recording telemetry metrics that can be used
 * for monitoring application performance, tracking business metrics, and analyzing system behavior.
 */
@interface SentryObjCMetricsApi : NSObject

/**
 * Records a count metric for the specified key with attributes.
 *
 * Use this to increment or set a discrete occurrence count associated with a metric key,
 * such as the number of events, requests, or errors.
 *
 * @param key A namespaced identifier for the metric (for example, "network.request.count").
 * @param value The count value to record.
 * @param attributes Dictionary of attributes to attach to the metric.
 */
- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value
          attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;

/**
 * Records a count metric for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The count value to record.
 */
- (void)countWithKey:(NSString *)key value:(NSUInteger)value;

/**
 * Records a count metric with a value of 1 for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 */
- (void)countWithKey:(NSString *)key;

/**
 * Records a distribution metric for the specified key with a unit and attributes.
 *
 * Use this to track the distribution of a value over time, such as response times,
 * request durations, or any measurable quantity where you want to analyze statistical
 * properties (mean, median, percentiles, etc.).
 *
 * @param key A namespaced identifier for the metric (for example, "http.request.duration").
 * @param value The value to record in the distribution.
 * @param unit Optional unit of measurement (e.g., millisecond, byte, percent).
 * @param attributes Dictionary of attributes to attach to the metric.
 */
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable SentryObjCUnit *)unit
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;

/**
 * Records a distribution metric for the specified key with a unit.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The value to record in the distribution.
 * @param unit Optional unit of measurement.
 */
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable SentryObjCUnit *)unit;

/**
 * Records a distribution metric for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The value to record in the distribution.
 */
- (void)distributionWithKey:(NSString *)key value:(double)value;

/**
 * Records a gauge metric for the specified key with a unit and attributes.
 *
 * Use this to track a value that can go up and down over time, such as current memory usage,
 * queue depth, active connections, or any metric that represents a current state rather
 * than an incrementing counter.
 *
 * @param key A namespaced identifier for the metric (for example, "memory.usage" or "queue.depth").
 * @param value The current gauge value to record.
 * @param unit Optional unit of measurement (e.g., millisecond, byte, percent).
 * @param attributes Dictionary of attributes to attach to the metric.
 */
- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable SentryObjCUnit *)unit
          attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;

/**
 * Records a gauge metric for the specified key with a unit.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The current gauge value to record.
 * @param unit Optional unit of measurement.
 */
- (void)gaugeWithKey:(NSString *)key value:(double)value unit:(nullable SentryObjCUnit *)unit;

/**
 * Records a gauge metric for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The current gauge value to record.
 */
- (void)gaugeWithKey:(NSString *)key value:(double)value;

@end

NS_ASSUME_NONNULL_END
