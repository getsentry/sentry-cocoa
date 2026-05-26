#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCMetricValue;
@class SentryObjCUnit;
@class SentryObjCAttributeContent;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMetric : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) SentryObjCId *traceId;
@property (nonatomic, strong, nullable) SentryObjCSpanId *spanId;
@property (nonatomic, strong) SentryObjCMetricValue *value;
@property (nonatomic, strong, nullable) SentryObjCUnit *unit;
@property (nonatomic, copy) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;

@end

NS_ASSUME_NONNULL_END
