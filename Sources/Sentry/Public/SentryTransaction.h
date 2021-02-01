#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentrySpanContext, SentryTransactionContext, SentryHub;

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
@property (nonatomic, copy) NSString *_Nullable spanDescription;

/**
 * Short code identifying the type of operation the transaction is measuring.
 */
@property (nonatomic, copy) NSString *_Nullable operation;

/**
 * Describes the status of the Transaction
 */
@property (nonatomic) enum SentrySpanStatus status;

/**
 * Init a SentryTransaction with given name and set other fields by default
 * @param name Transaction name
 * @return SentryTransaction
 */
- (instancetype)initWithName:(NSString *)name;

/**
 * Init a SentryTransaction with given transaction context and hub and set other fields by default
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 * @return SentryTransaction
 */

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                    andHub:(SentryHub *_Nullable)hub;

/**
 * Init a SentryTransaction with given name, span context and hub and set other fields by default
 * @param name Transaction name
 * @param spanContext Span context
 * @param hub A hub to bind this transaction
 * @return SentryTransaction
 */
- (instancetype)initWithName:(NSString *)name
                 spanContext:(SentrySpanContext *)spanContext
                      andHub:(SentryHub *_Nullable)hub;

/**
 * Finishes the transaction by setting the end time and capturing the transaction with binded hub.
 */
- (void)finish;

@end

NS_ASSUME_NONNULL_END
