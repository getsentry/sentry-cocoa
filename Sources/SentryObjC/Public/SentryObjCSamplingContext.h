#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Context passed to the @c tracesSampler callback to determine the sample rate for a transaction.
 * Contains the transaction context and optional custom sampling data.
 */
@interface SentryObjCSamplingContext : NSObject
SENTRY_NO_INIT

/// The context of the transaction being sampled.
@property (nonatomic, readonly, strong) SentryObjCTransactionContext *transactionContext;

/// Custom data used for sampling.
@property (nonatomic, readonly, strong, nullable)
    NSDictionary<NSString *, id> *customSamplingContext;

/**
 * Init a sampling context.
 * @param transactionContext The context of the transaction being sampled.
 */
- (instancetype)initWithTransactionContext:(SentryObjCTransactionContext *)transactionContext;

/**
 * Init a sampling context.
 * @param transactionContext The context of the transaction being sampled.
 * @param customSamplingContext Custom data used for sampling.
 */
- (instancetype)initWithTransactionContext:(SentryObjCTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@end

NS_ASSUME_NONNULL_END
