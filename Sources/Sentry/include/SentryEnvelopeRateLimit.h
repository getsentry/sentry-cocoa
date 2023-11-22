#import "SentryDefines.h"
#import "SentryRateLimits.h"

@protocol SentryEnvelopeRateLimitDelegate;

@class SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EnvelopeRateLimit)
@interface SentryEnvelopeRateLimit : SENTRY_BASE_OBJECT

- (instancetype)initWithRateLimits:(id<SentryRateLimits>)sentryRateLimits;

/**
 * Removes SentryEnvelopItems for which a rate limit is active.
 */
- (SentryEnvelope *)removeRateLimitedItems:(SentryEnvelope *)envelope;

- (void)setDelegate:(id<SentryEnvelopeRateLimitDelegate>)delegate;

@end

@protocol SentryEnvelopeRateLimitDelegate <NSObject>

- (void)envelopeItemDropped:(SentryDataCategory)dataCategory;

@end

NS_ASSUME_NONNULL_END
