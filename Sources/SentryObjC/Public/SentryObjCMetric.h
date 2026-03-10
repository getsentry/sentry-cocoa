#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

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

/// Timestamp when the metric was recorded.
@property (nonatomic, readonly) NSDate *timestamp;

/// Metric name (e.g., "response_time", "cache_hit_rate").
@property (nonatomic, readonly) NSString *name;

/// Trace ID for correlating this metric with a distributed trace.
@property (nonatomic, readonly) SentryId *traceId;

/// Optional span ID for correlating this metric with a specific span.
@property (nonatomic, readonly, nullable) SentrySpanId *spanId;

/// The metric value (counter, gauge, distribution, or set).
@property (nonatomic, readonly) SentryObjCMetricValue *value;

/// Unit of measurement (e.g., "milliseconds", "bytes", "percent").
@property (nonatomic, readonly, nullable) NSString *unit;

/// Additional structured attributes for filtering and grouping.
@property (nonatomic, readonly) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;

@end

NS_ASSUME_NONNULL_END
