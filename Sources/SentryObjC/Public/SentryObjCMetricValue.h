#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the numeric value of a metric with type-safe distinction between integers and doubles.
 *
 * This class provides type safety to prevent accidentally mixing integer and floating-point values,
 * especially useful in @c beforeSendMetric callbacks where you need to ensure counters remain
 * integers and distributions remain doubles.
 */
@interface SentryObjCMetricValue : NSObject
SENTRY_NO_INIT

/// Creates a counter metric value with incrementing integer values (e.g., request counts).
+ (instancetype)counter:(NSUInteger)value;
/// Creates a gauge metric value representing the current value at a point in time (e.g., active
/// connections).
+ (instancetype)gauge:(double)value;
/// Creates a distribution metric value for statistical aggregation (e.g., response times).
+ (instancetype)distribution:(double)value;

/// Returns @c YES if this metric value is a counter.
@property (nonatomic, readonly) BOOL isCounter;
/// Returns @c YES if this metric value is a gauge.
@property (nonatomic, readonly) BOOL isGauge;
/// Returns @c YES if this metric value is a distribution.
@property (nonatomic, readonly) BOOL isDistribution;

/// The counter value. Returns 0 if the metric value is not a counter.
@property (nonatomic, readonly) NSUInteger counterValue;
/// The gauge value. Returns 0 if the metric value is not a gauge.
@property (nonatomic, readonly) double gaugeValue;
/// The distribution value. Returns 0 if the metric value is not a distribution.
@property (nonatomic, readonly) double distributionValue;

@end

NS_ASSUME_NONNULL_END
