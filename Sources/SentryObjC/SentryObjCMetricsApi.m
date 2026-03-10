#import "SentryObjCMetricsApi.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSObject (SentryObjCMetricsApiDefaults)

- (void)countWithKey:(NSString *)key
{
    if ([self conformsToProtocol:@protocol(SentryObjCMetricsApi)]) {
        [(id<SentryObjCMetricsApi>)self countWithKey:key value:1 attributes:nil];
    }
}

- (void)countWithKey:(NSString *)key value:(NSUInteger)value
{
    if ([self conformsToProtocol:@protocol(SentryObjCMetricsApi)]) {
        [(id<SentryObjCMetricsApi>)self countWithKey:key value:value attributes:nil];
    }
}

- (void)distributionWithKey:(NSString *)key value:(double)value
{
    if ([self conformsToProtocol:@protocol(SentryObjCMetricsApi)]) {
        [(id<SentryObjCMetricsApi>)self distributionWithKey:key
                                                      value:value
                                                       unit:nil
                                                 attributes:nil];
    }
}

- (void)distributionWithKey:(NSString *)key value:(double)value unit:(nullable NSString *)unit
{
    if ([self conformsToProtocol:@protocol(SentryObjCMetricsApi)]) {
        [(id<SentryObjCMetricsApi>)self distributionWithKey:key
                                                      value:value
                                                       unit:unit
                                                 attributes:nil];
    }
}

- (void)gaugeWithKey:(NSString *)key value:(double)value
{
    if ([self conformsToProtocol:@protocol(SentryObjCMetricsApi)]) {
        [(id<SentryObjCMetricsApi>)self gaugeWithKey:key value:value unit:nil attributes:nil];
    }
}

- (void)gaugeWithKey:(NSString *)key value:(double)value unit:(nullable NSString *)unit
{
    if ([self conformsToProtocol:@protocol(SentryObjCMetricsApi)]) {
        [(id<SentryObjCMetricsApi>)self gaugeWithKey:key value:value unit:unit attributes:nil];
    }
}

@end

NS_ASSUME_NONNULL_END
