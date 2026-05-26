#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMetricValue : NSObject

+ (instancetype)counter:(NSUInteger)value;
+ (instancetype)gauge:(double)value;
+ (instancetype)distribution:(double)value;

@property (nonatomic, readonly) BOOL isCounter;
@property (nonatomic, readonly) BOOL isGauge;
@property (nonatomic, readonly) BOOL isDistribution;

@property (nonatomic, readonly) NSUInteger counterValue;
@property (nonatomic, readonly) double gaugeValue;
@property (nonatomic, readonly) double distributionValue;

@end

NS_ASSUME_NONNULL_END
