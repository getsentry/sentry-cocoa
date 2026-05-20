#import <Foundation/Foundation.h>

@class SOCSentryTransactionContext;

NS_ASSUME_NONNULL_BEGIN

/// Context passed to the `tracesSampler` callback.
@interface SOCSentrySamplingContext : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTransactionContext:(SOCSentryTransactionContext *)transactionContext;
- (instancetype)initWithTransactionContext:(SOCSentryTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@property (nonatomic, readonly, strong) SOCSentryTransactionContext *transactionContext;
@property (nonatomic, readonly, copy, nullable) NSDictionary<NSString *, id> *customSamplingContext;

@end

NS_ASSUME_NONNULL_END
