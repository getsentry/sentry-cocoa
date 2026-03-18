#import "SentryMetricValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryMetricValue ()
@property (nonatomic, readwrite) SentryMetricValueType type;
@property (nonatomic, readwrite) unsigned long long counterValue;
@property (nonatomic, readwrite) double gaugeValue;
@property (nonatomic, readwrite) double distributionValue;
@end

@implementation SentryMetricValue

+ (instancetype)counterWithValue:(unsigned long long)value
{
    SentryMetricValue *obj = [[SentryMetricValue alloc] init];
    obj->_type = SentryMetricValueTypeCounter;
    obj->_counterValue = value;
    return obj;
}

+ (instancetype)gaugeWithValue:(double)value
{
    SentryMetricValue *obj = [[SentryMetricValue alloc] init];
    obj->_type = SentryMetricValueTypeGauge;
    obj->_gaugeValue = value;
    return obj;
}

+ (instancetype)distributionWithValue:(double)value
{
    SentryMetricValue *obj = [[SentryMetricValue alloc] init];
    obj->_type = SentryMetricValueTypeDistribution;
    obj->_distributionValue = value;
    return obj;
}

@end

NS_ASSUME_NONNULL_END
