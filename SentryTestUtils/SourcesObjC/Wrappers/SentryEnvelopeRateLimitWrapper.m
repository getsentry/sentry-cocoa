#import "Wrappers/SentryEnvelopeRateLimitWrapper.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentrySwift.h"

@implementation SentryTestEnvelopeRateLimitDelegateWrapper
- (void)envelopeItemDropped:(SentryEnvelopeItem *)envelopeItem
               withCategory:(SentryDataCategory)category
{
    [self wrapper_envelopeItemDropped:envelopeItem withCategory:category];
}

- (void)wrapper_envelopeItemDropped:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelopeItem))envelopeItem
                       withCategory:(NSUInteger)category
{
}
@end
