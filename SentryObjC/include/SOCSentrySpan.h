#import <Foundation/Foundation.h>
#import "SOCSentrySampleDecision.h"
#import "SOCSentrySpanStatus.h"

@class SOCSentryId;
@class SOCSentrySpanId;
@class SOCSentryTraceContext;
@class SOCSentryTraceHeader;

NS_ASSUME_NONNULL_BEGIN

/// Concrete wrapper around the underlying Sentry span protocol.
@interface SOCSentrySpan : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, strong) SOCSentryId *traceId;
@property (nonatomic, strong) SOCSentrySpanId *spanId;
@property (nonatomic, strong, nullable) SOCSentrySpanId *parentSpanId;
@property (nonatomic) SOCSentrySampleDecision sampled;
@property (nonatomic, copy) NSString *operation;
@property (nonatomic, copy) NSString *origin;
@property (nonatomic, copy, nullable) NSString *spanDescription;
@property (nonatomic) SOCSentrySpanStatus status;
@property (nonatomic, copy, nullable) NSDate *timestamp;
@property (nonatomic, copy, nullable) NSDate *startTimestamp;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *data;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly, strong, nullable) SOCSentryTraceContext *traceContext;

- (SOCSentrySpan *)startChildWithOperation:(NSString *)operation;
- (SOCSentrySpan *)startChildWithOperation:(NSString *)operation
                                  description:(nullable NSString *)description;

- (void)setDataValue:(nullable id)value forKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key;
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;
- (void)removeTagForKey:(NSString *)key;
- (void)setMeasurement:(NSString *)name value:(NSNumber *)value;

- (void)finish;
- (void)finishWithStatus:(SOCSentrySpanStatus)status;

- (SOCSentryTraceHeader *)toTraceHeader;
- (nullable NSString *)baggageHttpHeader;

@end

NS_ASSUME_NONNULL_END
