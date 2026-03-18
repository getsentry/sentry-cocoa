#import "SentryMetricsApiImpl.h"

NS_ASSUME_NONNULL_BEGIN

// Forward declare SentryObjCBridge to avoid importing headers that require modules.
// At link time, the actual implementation from SentryObjCBridge will be used.
@interface SentryObjCBridge : NSObject
+ (void)metricsCountWithKey:(NSString *)key
                      value:(NSUInteger)value
                 attributes:(NSDictionary<NSString *, id> *)attributes;

+ (void)metricsDistributionWithKey:(NSString *)key
                             value:(double)value
                              unit:(nullable NSString *)unit
                        attributes:(NSDictionary<NSString *, id> *)attributes;

+ (void)metricsGaugeWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable NSString *)unit
                 attributes:(NSDictionary<NSString *, id> *)attributes;
@end

@implementation SentryMetricsApiImpl

- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value
          attributes:(nullable NSDictionary<NSString *, SentryAttributeContent *> *)attributes
{
    [SentryObjCBridge metricsCountWithKey:key value:value attributes:attributes ?: @{ }];
}

- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable NSString *)unit
                 attributes:
                     (nullable NSDictionary<NSString *, SentryAttributeContent *> *)attributes
{
    [SentryObjCBridge metricsDistributionWithKey:key
                                           value:value
                                            unit:unit
                                      attributes:attributes ?: @{ }];
}

- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable NSString *)unit
          attributes:(nullable NSDictionary<NSString *, SentryAttributeContent *> *)attributes
{
    [SentryObjCBridge metricsGaugeWithKey:key value:value unit:unit attributes:attributes ?: @{ }];
}

@end

NS_ASSUME_NONNULL_END
