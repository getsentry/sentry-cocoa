#import <Foundation/Foundation.h>

#import "SentryObjCSampleDecision.h"
#import "SentryObjCSerializable.h"
#import "SentryObjCSpanContext.h"
#import "SentryObjCSpanStatus.h"

@class SentryId;
@class SentryMeasurementUnit;
@class SentrySpanId;
@class SentryTraceContext;
@class SentryTraceHeader;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for a span in a trace.
 *
 * @see SentrySDK
 * @see SentryTransactionContext
 */
@protocol SentrySpan <SentrySerializable>

@property (nonatomic, strong) SentryId *traceId;
@property (nonatomic, strong) SentrySpanId *spanId;
@property (nullable, nonatomic, strong) SentrySpanId *parentSpanId;
@property (nonatomic) SentrySampleDecision sampled;
@property (nonatomic, copy) NSString *operation;
@property (nonatomic, copy) NSString *origin;
@property (nullable, nonatomic, copy) NSString *spanDescription;
@property (nonatomic) SentrySpanStatus status;
@property (nullable, nonatomic, strong) NSDate *timestamp;
@property (nullable, nonatomic, strong) NSDate *startTimestamp;
@property (readonly) NSDictionary<NSString *, id> *data;
@property (readonly) NSDictionary<NSString *, NSString *> *tags;
@property (readonly) BOOL isFinished;
@property (nullable, nonatomic, readonly) SentryTraceContext *traceContext;

- (id<SentrySpan>)startChildWithOperation:(NSString *)operation;
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description;
- (void)setDataValue:(nullable id)value forKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setMeasurement:(NSString *)name value:(NSNumber *)value;
- (void)setMeasurement:(NSString *)name value:(NSNumber *)value unit:(SentryMeasurementUnit *)unit;
- (void)finish;
- (void)finishWithStatus:(SentrySpanStatus)status;
- (SentryTraceHeader *)toTraceHeader;
- (nullable NSString *)baggageHttpHeader;
- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
