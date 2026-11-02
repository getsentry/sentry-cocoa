#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCAttributeContent;
@class SentryObjCMetricOptions;
@class SentryObjCUnit;

NS_ASSUME_NONNULL_BEGIN

/**
 * API for recording metrics (counters, distributions, and gauges) in Sentry.
 *
 * Provides a type-safe API for recording telemetry metrics that can be used
 * for monitoring application performance, tracking business metrics, and analyzing system behavior.
 */
@interface SentryObjCMetricsApi : NSObject
SENTRY_NO_INIT

/**
 * Records a count metric with the specified name.
 *
 * Use this to increment or set a discrete occurrence count associated with a metric name,
 * such as the number of events, requests, or errors.
 *
 * @param name A namespaced identifier for the metric (for example, "network.request.count").
 * @param value The count value to record.
 * @param options Attributes, scope and timestamp of the metric. Count metrics ignore the unit.
 */
- (void)count:(NSString *)name value:(NSUInteger)value options:(SentryObjCMetricOptions *)options;

/**
 * Records a count metric with the specified name.
 *
 * @param name A namespaced identifier for the metric.
 * @param value The count value to record.
 */
- (void)count:(NSString *)name value:(NSUInteger)value;

/**
 * Records a count metric with a value of 1 for the specified name.
 *
 * @param name A namespaced identifier for the metric.
 */
- (void)count:(NSString *)name;

/**
 * Records a distribution metric with the specified name.
 *
 * Use this to track the distribution of a value over time, such as response times,
 * request durations, or any measurable quantity where you want to analyze statistical
 * properties (mean, median, percentiles, etc.).
 *
 * @param name A namespaced identifier for the metric (for example, "http.request.duration").
 * @param value The value to record in the distribution.
 * @param options Unit, attributes, scope and timestamp of the metric.
 */
- (void)distribution:(NSString *)name
               value:(double)value
             options:(SentryObjCMetricOptions *)options;

/**
 * Records a distribution metric with the specified name.
 *
 * @param name A namespaced identifier for the metric.
 * @param value The value to record in the distribution.
 */
- (void)distribution:(NSString *)name value:(double)value;

/**
 * Records a gauge metric with the specified name.
 *
 * Use this to track a value that can go up and down over time, such as current memory usage,
 * queue depth, active connections, or any metric that represents a current state rather
 * than an incrementing counter.
 *
 * @param name A namespaced identifier for the metric (for example, "memory.usage" or
 * "queue.depth").
 * @param value The current gauge value to record.
 * @param options Unit, attributes, scope and timestamp of the metric.
 */
- (void)gauge:(NSString *)name value:(double)value options:(SentryObjCMetricOptions *)options;

/**
 * Records a gauge metric with the specified name.
 *
 * @param name A namespaced identifier for the metric.
 * @param value The current gauge value to record.
 */
- (void)gauge:(NSString *)name value:(double)value;

#if !SDK_V10
/**
 * Records a count metric for the specified key with attributes.
 *
 * Use this to increment or set a discrete occurrence count associated with a metric key,
 * such as the number of events, requests, or errors.
 *
 * @param key A namespaced identifier for the metric (for example, "network.request.count").
 * @param value The count value to record.
 * @param attributes Dictionary of attributes to attach to the metric.
 * @deprecated Use the options-based method instead.
 */
- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value
          attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
    __attribute__((
        deprecated("Use count:value:options: instead. This method will be removed in v10.")));

/**
 * Records a count metric for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The count value to record.
 * @deprecated Use the options-based method instead.
 */
- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value __attribute__((deprecated(
                         "Use count:value:options: instead. This method will be removed in v10.")));

/**
 * Records a count metric with a value of 1 for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @deprecated Use the options-based method instead.
 */
- (void)countWithKey:(NSString *)key __attribute__((deprecated(
                         "Use count:value:options: instead. This method will be removed in v10.")));

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
 * @deprecated Use the options-based method instead.
 */
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable SentryObjCUnit *)unit
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
    __attribute__((deprecated(
        "Use distribution:value:options: instead. This method will be removed in v10.")));

/**
 * Records a distribution metric for the specified key with a unit.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The value to record in the distribution.
 * @param unit Optional unit of measurement.
 * @deprecated Use the options-based method instead.
 */
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable SentryObjCUnit *)unit
    __attribute__((deprecated(
        "Use distribution:value:options: instead. This method will be removed in v10.")));

/**
 * Records a distribution metric for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The value to record in the distribution.
 * @deprecated Use the options-based method instead.
 */
- (void)distributionWithKey:(NSString *)key
                      value:(double)value
    __attribute__((deprecated(
        "Use distribution:value:options: instead. This method will be removed in v10.")));

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
 * @deprecated Use the options-based method instead.
 */
- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable SentryObjCUnit *)unit
          attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
    __attribute__((
        deprecated("Use gauge:value:options: instead. This method will be removed in v10.")));

/**
 * Records a gauge metric for the specified key with a unit.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The current gauge value to record.
 * @param unit Optional unit of measurement.
 * @deprecated Use the options-based method instead.
 */
- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable SentryObjCUnit *)unit __attribute__((deprecated(
                         "Use gauge:value:options: instead. This method will be removed in v10.")));

/**
 * Records a gauge metric for the specified key.
 *
 * @param key A namespaced identifier for the metric.
 * @param value The current gauge value to record.
 * @deprecated Use the options-based method instead.
 */
- (void)gaugeWithKey:(NSString *)key
               value:(double)value __attribute__((deprecated(
                         "Use gauge:value:options: instead. This method will be removed in v10.")));

#endif // !SDK_V10

#pragma mark - Testing

#if SENTRY_TEST || SENTRY_TEST_CI
- (instancetype)initWithTestApi:(NSObject *)api;
#endif

@end

NS_ASSUME_NONNULL_END
