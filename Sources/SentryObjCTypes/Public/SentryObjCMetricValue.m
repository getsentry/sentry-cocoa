#import "SentryObjCMetricValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMetricValue ()
@property (nonatomic, readwrite) SentryObjCMetricValueType type;
@property (nonatomic, readwrite) unsigned long long counterValue;
@property (nonatomic, readwrite) double gaugeValue;
@property (nonatomic, readwrite) double distributionValue;
@end

@implementation SentryObjCMetricValue

+ (instancetype)counterWithValue:(unsigned long long)value
{
    SentryObjCMetricValue *obj = [[SentryObjCMetricValue alloc] init];
    obj->_type = SentryObjCMetricValueTypeCounter;
    obj->_counterValue = value;
    return obj;
}

+ (instancetype)gaugeWithValue:(double)value
{
    SentryObjCMetricValue *obj = [[SentryObjCMetricValue alloc] init];
    obj->_type = SentryObjCMetricValueTypeGauge;
    obj->_gaugeValue = value;
    return obj;
}

+ (instancetype)distributionWithValue:(double)value
{
    SentryObjCMetricValue *obj = [[SentryObjCMetricValue alloc] init];
    obj->_type = SentryObjCMetricValueTypeDistribution;
    obj->_distributionValue = value;
    return obj;
}

@end

NS_ASSUME_NONNULL_END
