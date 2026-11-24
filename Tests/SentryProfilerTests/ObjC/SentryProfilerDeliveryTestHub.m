#import "SentryProfilerDeliveryTestHub.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED

@implementation SentryProfilerDeliveryTestHub
- (void)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope
{
    self.transactionCount++;
    self.lastTransaction = transaction;
    self.lastScope = scope;
}

- (void)captureTransaction:(SentryTransaction *)transaction
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    [self captureTransaction:transaction withScope:scope];
    self.lastAdditionalEnvelopeItems = additionalEnvelopeItems;
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    self.envelopeCount++;
    self.lastEnvelope = envelope;
}
@end

#endif
