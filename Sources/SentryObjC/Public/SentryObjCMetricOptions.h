#import <Foundation/Foundation.h>

@class SentryObjCAttributeContent;
@class SentryObjCScope;
@class SentryObjCUnit;

NS_ASSUME_NONNULL_BEGIN

/**
 * Optional values for recording a metric with @c SentryObjCMetricsApi.
 *
 * Mirrors the @c options parameter of @c Sentry.metrics.count(name, value, options) and its gauge
 * and distribution counterparts in the other Sentry SDKs.
 */
@interface SentryObjCMetricOptions : NSObject

/**
 * The unit of measurement of the metric value.
 *
 * Only used by gauge and distribution metrics. Count metrics ignore it.
 */
@property (nonatomic, strong, nullable) SentryObjCUnit *unit;

/**
 * Attributes to attach to the metric. Defaults to an empty dictionary.
 *
 * Attributes passed here take precedence over scope attributes with the same key.
 */
@property (nonatomic, copy) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;

/**
 * The scope to capture the metric with.
 *
 * The scope is applied on top of the global scope. When @c nil, the metric uses the current scope
 * of the calling thread, if any.
 */
@property (nonatomic, strong, nullable) SentryObjCScope *scope;

/**
 * The time the metric was recorded. When @c nil, the SDK uses the time the metric is captured.
 */
@property (nonatomic, strong, nullable) NSDate *timestamp;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
