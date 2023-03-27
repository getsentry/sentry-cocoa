#import "SentrySampleDecision.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;
@class SentryThread;

NS_SWIFT_NAME(TransactionContext)
@interface SentryTransactionContext : SentrySpanContext
SENTRY_NO_INIT

/**
 * Transaction name
 */
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SentryTransactionNameSource nameSource;

/**
 * Parent sampled
 */
@property (nonatomic) SentrySampleDecision parentSampled;

/**
 * Sample rate used for this transaction
 */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled;

/**
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param traceId Trace Id
 * @param spanId Span Id
 * @param parentSpanId Parent span id
 * @param parentSampled Whether the parent is sampled
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled;

@end

NS_ASSUME_NONNULL_END
