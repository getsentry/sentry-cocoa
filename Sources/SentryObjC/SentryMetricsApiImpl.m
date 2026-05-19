#import "SentryMetricsApiImpl.h"

#if __has_include(<SentryObjCCompat/SentryObjCAttributeContent.h>)
#    import <SentryObjCCompat/SentryObjCAttributeContent.h>
#else
#    import "SentryObjCAttributeContent.h"
#endif

// Forward declarations of SentryObjCBridge (see SentryObjCSDK.m for the full
// rationale).  Signature drift is only caught at link time / runtime — a
// shared @protocol in SentryObjCCompat would provide compile-time safety.
@interface SentryObjCBridge : NSObject
+ (void)metricsCountWithKey:(NSString *)key
                      value:(NSUInteger)value
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;
+ (void)metricsDistributionWithKey:(NSString *)key
                             value:(double)value
                              unit:(nullable NSString *)unit
                        attributes:
                            (NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;
+ (void)metricsGaugeWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable NSString *)unit
                 attributes:(NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes;
@end

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMetricsApiImpl

- (void)countWithKey:(NSString *)key
               value:(NSUInteger)value
          attributes:(nullable NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
{
    [SentryObjCBridge metricsCountWithKey:key value:value attributes:attributes ?: @{ }];
}

- (void)distributionWithKey:(NSString *)key
                      value:(double)value
                       unit:(nullable NSString *)unit
                 attributes:
                     (nullable NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
{
    [SentryObjCBridge metricsDistributionWithKey:key
                                           value:value
                                            unit:unit
                                      attributes:attributes ?: @{ }];
}

- (void)gaugeWithKey:(NSString *)key
               value:(double)value
                unit:(nullable NSString *)unit
          attributes:(nullable NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
{
    [SentryObjCBridge metricsGaugeWithKey:key value:value unit:unit attributes:attributes ?: @{ }];
}

@end

NS_ASSUME_NONNULL_END
