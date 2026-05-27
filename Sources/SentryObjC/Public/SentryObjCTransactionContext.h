#import <Foundation/Foundation.h>
#if SWIFT_PACKAGE
#    import "SentryObjCSampleDecision.h"
#    import "SentryObjCSpanContext.h"
#    import "SentryObjCTransactionNameSource.h"
#else
#    import <SentryObjC/SentryObjCSampleDecision.h>
#    import <SentryObjC/SentryObjCSpanContext.h>
#    import <SentryObjC/SentryObjCTransactionNameSource.h>
#endif

@class SentryObjCId;
@class SentryObjCSpanId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Context for a transaction span, extending @c SentryObjCSpanContext with transaction-specific
 * information such as the transaction name, sample rates, and parent sampling decisions.
 */
@interface SentryObjCTransactionContext : SentryObjCSpanContext

/// The transaction name.
@property (nonatomic, readonly, copy) NSString *name;

/// The source of the transaction name.
@property (nonatomic, readonly) SentryObjCTransactionNameSource nameSource;

/// The rate of sampling for this transaction.
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/// Random value used to determine if the span is sampled.
@property (nonatomic, strong, nullable) NSNumber *sampleRand;

/// Whether the parent span was sampled.
@property (nonatomic) SentryObjCSampleDecision parentSampled;

/// Parent sample rate used for this transaction.
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;

/// Parent random value used to determine if the trace is sampled.
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;

/**
 * If app launch profiling is enabled via profile options and trace/profile samplers are defined,
 * SDK start will call the sampler function with this property set to @c YES, and the returned
 * value will be stored to disk for the next launch to calculate a sampling decision on whether
 * or not to run the profiler.
 */
@property (nonatomic, assign) BOOL forNextAppLaunch;

/**
 * @param name Transaction name.
 * @param operation The operation this span is measuring.
 */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/**
 * @param name Transaction name.
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 * @param sampleRate The sample rate used for this transaction.
 * @param sampleRand The random value used for sampling decisions.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentryObjCSampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;

/**
 * @param name Transaction name.
 * @param operation The operation this span is measuring.
 * @param traceId The trace id.
 * @param spanId The span id.
 * @param parentSpanId Parent span id.
 * @param parentSampled Whether the parent is sampled.
 * @param parentSampleRate The sample rate of the parent.
 * @param parentSampleRand The random value of the parent used for sampling.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryObjCId *)traceId
                      spanId:(SentryObjCSpanId *)spanId
                parentSpanId:(nullable SentryObjCSpanId *)parentSpanId
               parentSampled:(SentryObjCSampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@end

NS_ASSUME_NONNULL_END
