#import "SentryProfilingConditionals.h"
#import "SentrySampleDecision.h"
#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryId;
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

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * The profile associated with the transaction.
 * @note Only one profile may be associated with a transaction, but many transactions may be
 * associated with the same profile.
 */
@property (nonatomic, strong, nullable) SentryId *profileID;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

/**
 * Init a SentryTransactionContext with given name and set other fields by default
 *
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/**
 * Init a SentryTransactionContext with given name and set other fields by default
 *
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled;

/**
 * Init a SentryTransactionContext with given name, traceId, SpanId, parentSpanId and whether the
 * parent is sampled.
 *
 * @param name Transaction name
 * @param operation The operation this span is measuring.
 * @param traceId Trace Id
 * @param spanId Span Id
 * @param parentSpanId Parent span id
 * @param parentSampled Whether the parent is sampled
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled;

@end

NS_ASSUME_NONNULL_END
