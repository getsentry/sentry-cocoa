#import "SentryHub.h"
#import "SentryTracer.h"

@class SentryEnvelopeItem, SentryId, SentryScope, SentryTransaction, SentryDispatchQueueWrapper,
    SentryEnvelope, SentryNSTimerWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHub (Private)

@property (nonatomic, strong) NSArray<id<SentryIntegrationProtocol>> *installedIntegrations;
@property (nonatomic, strong) NSSet<NSString *> *installedIntegrationNames;

- (void)addInstalledIntegration:(id<SentryIntegrationProtocol>)integration name:(NSString *)name;
- (void)removeAllIntegrations;

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

- (SentryTracer *)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
                                    configure:(nullable SentryTracerConfigure)configure;

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope;

- (SentryId *)captureTransaction:(SentryTransaction *)transaction
                       withScope:(SentryScope *)scope
         additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;

- (void)captureEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
