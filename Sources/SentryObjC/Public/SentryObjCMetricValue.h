#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryObjCMetricValueType) {
    SentryObjCMetricValueTypeCounter,
    SentryObjCMetricValueTypeGauge,
    SentryObjCMetricValueTypeDistribution
};

/**
 * ObjC wrapper for SentryMetricValue (counter, gauge, or distribution).
 *
 * @see SentryObjCMetric
 */
@interface SentryObjCMetricValue : NSObject

@property (nonatomic, readonly) SentryObjCMetricValueType type;
@property (nonatomic, readonly) unsigned long long counterValue;
@property (nonatomic, readonly) double gaugeValue;
@property (nonatomic, readonly) double distributionValue;

+ (instancetype)counterWithValue:(unsigned long long)value;
+ (instancetype)gaugeWithValue:(double)value;
+ (instancetype)distributionWithValue:(double)value;

@end

NS_ASSUME_NONNULL_END
