#import <Foundation/Foundation.h>

@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Context passed to the traces sampler callback.
 *
 * Provides information needed to make dynamic sampling decisions for traces.
 * The sampler callback can inspect this context and return a sampling decision.
 *
 * @see SentryTracesSamplerCallback
 */
@interface SentrySamplingContext : NSObject

/**
 * Transaction context being sampled.
 *
 * Contains the transaction name, operation, and trace information.
 */
@property (nonatomic, readonly) SentryTransactionContext *transactionContext;

/**
 * Custom data provided for this sampling decision.
 *
 * Application-specific data that can influence the sampling decision.
 * For example, you might include user tier, request path, or feature flags.
 */
@property (nullable, nonatomic, readonly) NSDictionary<NSString *, id> *customSamplingContext;

/**
 * Creates a sampling context with a transaction context.
 *
 * @param transactionContext The transaction being sampled.
 * @return A new sampling context instance.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext;

/**
 * Creates a sampling context with custom data.
 *
 * @param transactionContext The transaction being sampled.
 * @param customSamplingContext Application-specific sampling data.
 * @return A new sampling context instance.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@end

NS_ASSUME_NONNULL_END
