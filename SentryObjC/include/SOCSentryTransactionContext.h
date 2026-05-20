#import <Foundation/Foundation.h>
#import "SOCSentrySampleDecision.h"
#import "SOCSentryTransactionNameSource.h"

@class SOCSentryId;
@class SOCSentrySpanId;

NS_ASSUME_NONNULL_BEGIN

/// Context describing a transaction's identity and sampling state.
@interface SOCSentryTransactionContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SOCSentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SOCSentryId *)traceId
                      spanId:(SOCSentrySpanId *)spanId
                parentSpanId:(nullable SOCSentrySpanId *)parentSpanId
               parentSampled:(SOCSentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) SOCSentryTransactionNameSource nameSource;
@property (nonatomic, strong, nullable) NSNumber *sampleRate;
@property (nonatomic, strong, nullable) NSNumber *sampleRand;
@property (nonatomic) SOCSentrySampleDecision parentSampled;
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;
@property (nonatomic) BOOL forNextAppLaunch;

// Inherited from the underlying SpanContext:
@property (nonatomic, readonly, strong) SOCSentryId *traceId;
@property (nonatomic, readonly, strong) SOCSentrySpanId *spanId;
@property (nonatomic, readonly, strong, nullable) SOCSentrySpanId *parentSpanId;
@property (nonatomic, readonly) SOCSentrySampleDecision sampled;
@property (nonatomic, readonly, copy) NSString *operation;
@property (nonatomic, readonly, copy, nullable) NSString *spanDescription;
@property (nonatomic, copy) NSString *origin;

@end

NS_ASSUME_NONNULL_END
