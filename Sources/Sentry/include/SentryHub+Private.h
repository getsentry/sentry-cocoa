#import "SentryHub.h"
#import "SentryTransactionContext+Private.h"

@class SentryEnvelopeItem, SentryId, SentryScope, SentryTransaction, SentryDispatchQueueWrapper,
    SentryTracer;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHub (Private)

@property (nonatomic, strong)
    NSMutableArray<NSObject<SentryIntegrationProtocol> *> *installedIntegrations;
@property (nonatomic, strong) NSMutableArray<NSString *> *installedIntegrationNames;

- (SentryClient *_Nullable)client;

- (void)captureCrashEvent:(SentryEvent *)event;

- (void)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

- (void)setSampleRandomValue:(NSNumber *)value;

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

- (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                nameSource:(SentryTransactionNameSource)source
                                 operation:(NSString *)operation;

- (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                nameSource:(SentryTransactionNameSource)source
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope;

- (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                              waitForChildren:(BOOL)waitForChildren
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext;

- (SentryTracer *)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
                                  idleTimeout:(NSTimeInterval)idleTimeout
                         dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope;

- (SentryId *)captureTransaction:(SentryTransaction *)transaction
                       withScope:(SentryScope *)scope
         additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;

@end

NS_ASSUME_NONNULL_END
