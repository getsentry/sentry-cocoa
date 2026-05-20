#import <Foundation/Foundation.h>
#import "SentryCompatSampleDecision.h"
#import "SentryCompatTransactionNameSource.h"

@class SentryCompatId;
@class SentryCompatSpanId;

NS_ASSUME_NONNULL_BEGIN

/// Context describing a transaction's identity and sampling state.
@interface SentryCompatTransactionContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentryCompatSampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryCompatId *)traceId
                      spanId:(SentryCompatSpanId *)spanId
                parentSpanId:(nullable SentryCompatSpanId *)parentSpanId
               parentSampled:(SentryCompatSampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) SentryCompatTransactionNameSource nameSource;
@property (nonatomic, strong, nullable) NSNumber *sampleRate;
@property (nonatomic, strong, nullable) NSNumber *sampleRand;
@property (nonatomic) SentryCompatSampleDecision parentSampled;
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;
@property (nonatomic) BOOL forNextAppLaunch;

// Inherited from the underlying SpanContext:
@property (nonatomic, readonly, strong) SentryCompatId *traceId;
@property (nonatomic, readonly, strong) SentryCompatSpanId *spanId;
@property (nonatomic, readonly, strong, nullable) SentryCompatSpanId *parentSpanId;
@property (nonatomic, readonly) SentryCompatSampleDecision sampled;
@property (nonatomic, readonly, copy) NSString *operation;
@property (nonatomic, readonly, copy, nullable) NSString *spanDescription;
@property (nonatomic, copy) NSString *origin;

@end

NS_ASSUME_NONNULL_END
