#import <Foundation/Foundation.h>

@class SentryCompatTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/// Context passed to the `tracesSampler` callback.
@interface SentryCompatSamplingContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTransactionContext:(SentryCompatTransactionContext *)transactionContext;
- (instancetype)initWithTransactionContext:(SentryCompatTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@property (nonatomic, readonly, strong) SentryCompatTransactionContext *transactionContext;
@property (nonatomic, readonly, copy, nullable) NSDictionary<NSString *, id> *customSamplingContext;

@end

NS_ASSUME_NONNULL_END
