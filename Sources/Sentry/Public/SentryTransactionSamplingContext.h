#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryTransactionContext;

NS_SWIFT_NAME(TransactionSamplingContext)
@interface SentryTransactionSamplingContext : NSObject

/**
 * Transaction context.
 */
@property (nonatomic, readonly) SentryTransactionContext * transactionContext;

/**
 * Custom data used for sampling.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, id> * customSamplingContext;

/**
 * Init a SentryTransactionSamplingContext
 *
 * @param transactionContext the context of the transaction being sampled.
 * @param customSamplingContext Custom data used for sampling.
 *
 * @return SenryTransactionSamplingContext
 */
- (instancetype) initWithTransactionContext:(SentryTransactionContext *) transactionContext
                      customSamplingContext:(NSDictionary<NSString *, id> *) customSamplingContext;

@end

NS_ASSUME_NONNULL_END
