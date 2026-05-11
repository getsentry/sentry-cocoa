#import <Foundation/Foundation.h>

@class SentryId;
@class SentrySpanId;
@class SentryObjCMetricValue;
@class SentryObjCAttributeContent;

NS_ASSUME_NONNULL_BEGIN

/**
 * Custom metric for application performance monitoring.
 *
 * Represents a single metric data point with optional trace correlation and attributes.
 * Used for tracking custom performance indicators beyond automatic instrumentation.
 *
 * @see SentryObjCMetricValue
 * @see SentryObjCAttributeContent
 */
@interface SentryObjCMetric : NSObject

/**
 * Creates a metric with the specified properties.
 *
 * @param timestamp When the metric was recorded.
 * @param name Metric name (e.g., "response_time").
 * @param traceId Trace ID for distributed tracing correlation.
 * @param spanId Optional span ID for span correlation.
 * @param value The metric value (counter, gauge, or distribution).
 * @param unit Optional unit of measurement.
 * @param attributes Additional structured attributes.
 * @return A new metric instance.
 */
- (instancetype)initWithTimestamp:(NSDate *)timestamp
                             name:(NSString *)name
                          traceId:(SentryId *)traceId
                           spanId:(nullable SentrySpanId *)spanId
                            value:(SentryObjCMetricValue *)value
                             unit:(nullable NSString *)unit
                       attributes:
                           (NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;

/// Timestamp when the metric was recorded.
@property (nonatomic, strong) NSDate *timestamp;

/// Metric name (e.g., "response_time", "cache_hit_rate").
@property (nonatomic, copy) NSString *name;

/// Trace ID for correlating this metric with a distributed trace.
@property (nonatomic, strong) SentryId *traceId;

/// Optional span ID for correlating this metric with a specific span.
@property (nonatomic, strong, nullable) SentrySpanId *spanId;

/// The metric value (counter, gauge, distribution, or set).
@property (nonatomic, strong) SentryObjCMetricValue *value;

/// Unit of measurement (e.g., "milliseconds", "bytes", "percent").
@property (nonatomic, copy, nullable) NSString *unit;

/// Additional structured attributes for filtering and grouping.
@property (nonatomic, copy) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;

@end

NS_ASSUME_NONNULL_END
