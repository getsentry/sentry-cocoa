#import "SentryMetricsApiImpl.h"

#if __has_include(<SentryObjCTypes/SentryObjCAttributeContent.h>)
#    import <SentryObjCTypes/SentryObjCAttributeContent.h>
#    import <SentryObjCTypes/SentryObjCBridging.h>
#else
#    import "SentryObjCAttributeContent.h"
#    import "SentryObjCBridging.h"
#endif

// SentryObjCBridge ships in the same SDK and conforms to SentryObjCBridging
// (declared in SentryObjCTypes). Adopting the protocol gives this file typed
// access to the bridge's class methods without importing SentryObjCBridge-Swift.h.
@interface SentryObjCBridge : NSObject <SentryObjCBridging>
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
