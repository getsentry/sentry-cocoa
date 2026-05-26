#import <Foundation/Foundation.h>

@class SentryObjCTransactionContext;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCSamplingContext : NSObject

@property (nonatomic, readonly, strong) SentryObjCTransactionContext *transactionContext;
@property (nonatomic, readonly, strong, nullable)
    NSDictionary<NSString *, id> *customSamplingContext;

- (instancetype)initWithTransactionContext:(SentryObjCTransactionContext *)transactionContext;
- (instancetype)initWithTransactionContext:(SentryObjCTransactionContext *)transactionContext
                     customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

@end

NS_ASSUME_NONNULL_END
