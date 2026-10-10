#import "SentryTestSDKBridge.h"

#import "SentryClient+Private.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryHttpTransport.h"
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

@implementation SentryTestSessionDelegateWrapper
- (SentrySession *)incrementSessionErrors
{
    return [self wrapper_incrementSessionErrors];
}

- (id)wrapper_incrementSessionErrors
{
    return nil;
}
@end

@implementation SentryTestSDKBridge
+ (SENTRY_SWIFT_MIGRATION_ID(id<SentryTransport>))
    makeHttpTransportWithDsn:(SENTRY_SWIFT_MIGRATION_ID(SentryDsn))dsn
           sendClientReports:(BOOL)sendClientReports
     cachedEnvelopeSendDelay:(NSTimeInterval)cachedEnvelopeSendDelay
                dateProvider:(SENTRY_SWIFT_MIGRATION_ID(id<SentryCurrentDateProvider>))dateProvider
                 fileManager:(SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager
              requestManager:(SENTRY_SWIFT_MIGRATION_ID(id<SentryRequestManager>))requestManager
              requestBuilder:(SENTRY_SWIFT_MIGRATION_ID(SentryNSURLRequestBuilder))requestBuilder
                  rateLimits:(SENTRY_SWIFT_MIGRATION_ID(id<SentryRateLimits>))rateLimits
           envelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
        dispatchQueueWrapper:(SENTRY_SWIFT_MIGRATION_ID(
                                 SentryDispatchQueueWrapper))dispatchQueueWrapper
                reachability:(SENTRY_SWIFT_MIGRATION_ID(SentryReachability))reachability
{
    return [[SentryHttpTransport alloc] initWithDsn:dsn
                                  sendClientReports:sendClientReports
                            cachedEnvelopeSendDelay:cachedEnvelopeSendDelay
                                       dateProvider:dateProvider
                                        fileManager:fileManager
                                     requestManager:requestManager
                                     requestBuilder:requestBuilder
                                         rateLimits:rateLimits
                                  envelopeRateLimit:envelopeRateLimit
                               dispatchQueueWrapper:dispatchQueueWrapper
                                       reachability:reachability];
}

+ (Class)httpTransportClass
{
    return [SentryHttpTransport class];
}
@end
