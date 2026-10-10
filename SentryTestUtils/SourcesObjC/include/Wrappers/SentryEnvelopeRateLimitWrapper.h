#import "SentryDefines.h"
#import <Foundation/Foundation.h>
@import _SentryPrivate;
#import "../../../../Sources/Sentry/include/SentryEnvelopeRateLimit.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryTestEnvelopeRateLimitDelegateWrapper : NSObject <SentryEnvelopeRateLimitDelegate>
- (void)wrapper_envelopeItemDropped:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelopeItem))envelopeItem
                       withCategory:(NSUInteger)category;
@end
NS_ASSUME_NONNULL_END
