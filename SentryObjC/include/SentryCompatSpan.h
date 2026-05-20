#import <Foundation/Foundation.h>
#import "SentryCompatSampleDecision.h"
#import "SentryCompatSpanStatus.h"

@class SentryCompatId;
@class SentryCompatSpanId;
@class SentryCompatTraceContext;
@class SentryCompatTraceHeader;

NS_ASSUME_NONNULL_BEGIN

/// Concrete wrapper around the underlying Sentry span protocol.
@interface SentryCompatSpan : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, strong) SentryCompatId *traceId;
@property (nonatomic, strong) SentryCompatSpanId *spanId;
@property (nonatomic, strong, nullable) SentryCompatSpanId *parentSpanId;
@property (nonatomic) SentryCompatSampleDecision sampled;
@property (nonatomic, copy) NSString *operation;
@property (nonatomic, copy) NSString *origin;
@property (nonatomic, copy, nullable) NSString *spanDescription;
@property (nonatomic) SentryCompatSpanStatus status;
@property (nonatomic, copy, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSDate *startTimestamp;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *data;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly, strong, nullable) SentryCompatTraceContext *traceContext;

- (SentryCompatSpan *)startChildWithOperation:(NSString *)operation;
- (SentryCompatSpan *)startChildWithOperation:(NSString *)operation
                                  description:(nullable NSString *)description;

- (void)setDataValue:(nullable id)value forKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setMeasurement:(NSString *)name value:(NSNumber *)value;

- (void)finish;
- (void)finishWithStatus:(SentryCompatSpanStatus)status;

- (SentryCompatTraceHeader *)toTraceHeader;
- (nullable NSString *)baggageHttpHeader;

@end

NS_ASSUME_NONNULL_END
