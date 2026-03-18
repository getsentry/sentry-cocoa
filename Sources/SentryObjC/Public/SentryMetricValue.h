#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Type of metric value.
 */
typedef NS_ENUM(NSInteger, SentryMetricValueType) {
    /// Monotonically increasing counter (e.g., total requests).
    SentryMetricValueTypeCounter,
    /// Single value snapshot (e.g., current memory usage).
    SentryMetricValueTypeGauge,
    /// Statistical distribution of values (e.g., response time percentiles).
    SentryMetricValueTypeDistribution
};

/**
 * Typed metric value: counter, gauge, or distribution.
 *
 * Use the factory methods to create instances of the appropriate type.
 *
 * @see SentryMetric
 */
@interface SentryMetricValue : NSObject

/// The type of metric value stored.
@property (nonatomic, readonly) SentryMetricValueType type;

/// Counter value, if @c type is @c SentryMetricValueTypeCounter.
@property (nonatomic, readonly) unsigned long long counterValue;

/// Gauge value, if @c type is @c SentryMetricValueTypeGauge.
@property (nonatomic, readonly) double gaugeValue;

/// Distribution value, if @c type is @c SentryMetricValueTypeDistribution.
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
