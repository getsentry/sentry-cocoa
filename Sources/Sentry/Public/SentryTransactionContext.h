#import "SentrySpanContext.h"

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanId;

NS_SWIFT_NAME(TransactionContext)
@interface SentryTransactionContext : SentrySpanContext

/**
 * Transaction name
 */
@property (nonatomic, readonly) NSString *name;

/**
 * Parent sampled
 */
@property (nonatomic) BOOL parentSampled;

/**
 * Init a SentryTransactionContext and set all fields by default
 *
 * @return SentryTransactionContext
 */
- (instancetype)init;

/**
 * Init a SentryTransactionContext with given name and set other fields by default
 *
 * @param name Transaction name
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name;

/**
 * Init a SentryTransactionContext with given name, traceId, SpanId, parentSpanId and whether the
 * parent is sampled.
 *
 * @param name Transaction name
 * @param traceId Trace Id
 * @param spanId Span Id
 * @param parentSpanId Parent span id
 * @param parentSampled Whether the parent is sampled
 *
 * @return SentryTransactionContext
 */
- (instancetype)initWithName:(NSString *)name
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
            andParentSampled:(BOOL)parentSampled;

@end

NS_ASSUME_NONNULL_END
