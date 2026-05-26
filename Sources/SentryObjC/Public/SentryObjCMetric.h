#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCMetricValue;
@class SentryObjCUnit;
@class SentryObjCAttributeContent;

NS_ASSUME_NONNULL_BEGIN

/**
 * A metric entry that captures metric data with associated attribute metadata.
 *
 * Use the @c options.beforeSendMetric callback to modify or filter metric data.
 */
@interface SentryObjCMetric : NSObject

/// The timestamp when the metric was recorded.
@property (nonatomic, strong) NSDate *timestamp;

/**
 * The name of the metric (e.g., "api.response_time", "db.query.duration").
 *
 * Metric names should follow a dot-separated hierarchical naming convention
 * to enable better organization and querying in Sentry.
 */
@property (nonatomic, copy) NSString *name;

/**
 * The trace ID to associate this metric with distributed tracing.
 *
 * This will be set to a valid non-empty value during processing by the buffer,
 * which applies scope-based attribute enrichment including trace context.
 */
@property (nonatomic, strong) SentryObjCId *traceId;

/**
 * The span ID of the span that was active when the metric was collected.
 *
 * Only set when there is an active span; a propagated span_id must not be used.
 */
@property (nonatomic, strong, nullable) SentryObjCSpanId *spanId;

/**
 * The numeric value of the metric.
 *
 * @note Counters use integer values, distributions and gauges use double values.
 */
@property (nonatomic, strong) SentryObjCMetricValue *value;

/**
 * The unit of measurement for the metric value (optional).
 *
 * Examples: "millisecond", "byte", "connection", "request". This helps
 * provide context for the metric value when viewing in Sentry.
 */
@property (nonatomic, strong, nullable) SentryObjCUnit *unit;

/**
 * A dictionary of structured attributes added to the metric.
 *
 * Attributes provide additional context and can be used for filtering and
 * grouping metrics in Sentry. Common attributes include endpoint names,
 * HTTP methods, status codes, etc.
 */
@property (nonatomic, copy) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;

@end

NS_ASSUME_NONNULL_END
