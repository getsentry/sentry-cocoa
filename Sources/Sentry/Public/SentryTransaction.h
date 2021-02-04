#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanContext, SentryTransactionContext, SentryHub, SentrySpan;

NS_SWIFT_NAME(Transaction)
@interface SentryTransaction : SentryEvent <SentrySerializable>
SENTRY_NO_INIT

/**
 * Transaction span id
 */
@property (readonly) SentrySpanId *spanId;

/**
 * Transaction trace id
 */
@property (readonly) SentryId *traceId;

/**
 * If transaction is sampled
 */
@property (readonly) BOOL isSampled;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nullable, nonatomic, copy) NSString *spanDescription;

/**
 * Short code identifying the type of operation the transaction is measuring.
 */
@property (nullable, nonatomic, copy) NSString *operation;

/**
 * Describes the status of the Transaction
 */
@property (nonatomic) enum SentrySpanStatus status;

/**
 * Init a SentryTransaction with given name and set other fields by default
 *
 * @param name Transaction name
 *
 * @return SentryTransaction
 */
- (instancetype)initWithName:(NSString *)name;

/**
 * Init a SentryTransaction with given transaction context and hub and set other fields by default
 *
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 *
 * @return SentryTransaction
 */

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                    andHub:(nullable SentryHub *)hub;

/**
 * Init a SentryTransaction with given name, span context and hub and set other fields by default
 *
 * @param name Transaction name
 * @param spanContext Span context
 * @param hub A hub to bind this transaction
 *
 * @return SentryTransaction
 */
- (instancetype)initWithName:(NSString *)name
                 spanContext:(SentrySpanContext *)spanContext
                      andHub:(nullable SentryHub *)hub;

/**
 * Finishes the transaction by setting the end time and capturing the transaction with binded hub.
 */
- (void)finish;

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 *
 * @return SentrySpan
 */
- (SentrySpan *)startChildWithOperation:(NSString *)operation NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (SentrySpan *)startChildWithOperation:(NSString *)operation
                         andDescription:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

@end

NS_ASSUME_NONNULL_END
