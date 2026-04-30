#import "SentryObjCMetric.h"
#import "SentryObjCAttributeContent.h"
#import "SentryObjCMetricValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMetric ()
@property (nonatomic, readwrite) NSDate *timestamp;
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) SentryId *traceId;
@property (nonatomic, readwrite, nullable) SentrySpanId *spanId;
@property (nonatomic, readwrite) SentryObjCMetricValue *value;
@property (nonatomic, readwrite, nullable) NSString *unit;
@property (nonatomic, readwrite) NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes;
@end

@implementation SentryObjCMetric

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithTimestamp:(NSDate *)timestamp
                             name:(NSString *)name
                          traceId:(SentryId *)traceId
                           spanId:(nullable SentrySpanId *)spanId
                            value:(SentryObjCMetricValue *)value
                             unit:(nullable NSString *)unit
                       attributes:
                           (NSDictionary<NSString *, SentryObjCAttributeContent *> *)attributes
{
    if (self = [super init]) {
        _timestamp = timestamp;
        _name = [name copy];
        _traceId = traceId;
        _spanId = spanId;
        _value = value;
        _unit = [unit copy];
        _attributes = [attributes copy];
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
