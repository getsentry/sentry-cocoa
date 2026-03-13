#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Type of metric value.
 */
typedef NS_ENUM(NSInteger, SentryObjCMetricValueType) {
    /// Monotonically increasing counter (e.g., total requests).
    SentryObjCMetricValueTypeCounter,
    /// Single value snapshot (e.g., current memory usage).
    SentryObjCMetricValueTypeGauge,
    /// Statistical distribution of values (e.g., response time percentiles).
    SentryObjCMetricValueTypeDistribution
};

/**
 * Typed metric value: counter, gauge, or distribution.
 *
 * Use the factory methods to create instances of the appropriate type.
 *
 * @see SentryObjCMetric
 */
@interface SentryObjCMetricValue : NSObject

/// The type of metric value stored.
@property (nonatomic, readonly) SentryObjCMetricValueType type;

/// Counter value, if @c type is @c SentryObjCMetricValueTypeCounter.
@property (nonatomic, readonly) unsigned long long counterValue;

/// Gauge value, if @c type is @c SentryObjCMetricValueTypeGauge.
@property (nonatomic, readonly) double gaugeValue;

/// Distribution value, if @c type is @c SentryObjCMetricValueTypeDistribution.
@property (nonatomic, readonly) double distributionValue;

/**
 * Creates a counter metric value.
 *
 * @param value The counter value (must increase monotonically).
 * @return A new metric value instance.
 */
+ (instancetype)counterWithValue:(unsigned long long)value;

/**
 * Creates a gauge metric value.
 *
 * @param value The gauge value (snapshot).
 * @return A new metric value instance.
 */
+ (instancetype)gaugeWithValue:(double)value;

/**
 * Creates a distribution metric value.
 *
 * @param value A sample value for the distribution.
 * @return A new metric value instance.
 */
+ (instancetype)distributionWithValue:(double)value;

@end

NS_ASSUME_NONNULL_END
