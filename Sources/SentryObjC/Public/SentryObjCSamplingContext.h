#import <Foundation/Foundation.h>

@class SentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Context passed to the traces sampler callback.
 *
 * @see SentryTracesSamplerCallback
 */
@interface SentrySamplingContext : NSObject

/** Transaction context being sampled. */
@property (nonatomic, readonly) SentryTransactionContext *transactionContext;

/** Custom data for sampling. */
@property (nullable, nonatomic, readonly) NSDictionary<NSString *, id> *customSamplingContext;

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext;

- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@end

NS_ASSUME_NONNULL_END
