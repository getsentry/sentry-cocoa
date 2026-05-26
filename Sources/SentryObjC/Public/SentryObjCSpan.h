#import "SentryObjCSampleDecision.h"
#import "SentryObjCSpanStatus.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCMeasurementUnit;
@class SentryObjCSpanId;
@class SentryObjCTraceContext;
@class SentryObjCTraceHeader;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCSpan : NSObject

@property (nonatomic, strong) SentryObjCId *traceId;
@property (nonatomic, strong) SentryObjCSpanId *spanId;
@property (nonatomic, strong, nullable) SentryObjCSpanId *parentSpanId;
@property (nonatomic) SentryObjCSampleDecision sampled;
@property (nonatomic, copy) NSString *operation;
@property (nonatomic, copy) NSString *origin;
@property (nonatomic, copy, nullable) NSString *spanDescription;
@property (nonatomic) SentryObjCSpanStatus status;
@property (nonatomic, strong, nullable) NSDate *timestamp;
@property (nonatomic, strong, nullable) NSDate *startTimestamp;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *data;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly, strong, nullable) SentryObjCTraceContext *traceContext;

- (SentryObjCSpan *)startChildWithOperation:(NSString *)operation;
- (SentryObjCSpan *)startChildWithOperation:(NSString *)operation
                                description:(nullable NSString *)description;
- (void)setDataValue:(nullable id)value forKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setMeasurementWithName:(NSString *)name value:(NSNumber *)value;
- (void)setMeasurementWithName:(NSString *)name
                         value:(NSNumber *)value
                          unit:(SentryObjCMeasurementUnit *)unit;
- (void)finish;
- (void)finishWithStatus:(SentryObjCSpanStatus)status;
- (SentryObjCTraceHeader *)toTraceHeader;
- (nullable NSString *)baggageHttpHeader;

@end

NS_ASSUME_NONNULL_END
