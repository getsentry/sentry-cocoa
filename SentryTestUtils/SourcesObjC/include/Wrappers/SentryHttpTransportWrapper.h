#import "SentryDefines.h"
#import <Foundation/Foundation.h>
@import _SentryPrivate;

@class SentryEnvelopeRateLimit;

NS_ASSUME_NONNULL_BEGIN

// Keep the generated Swift interface in the implementation, outside the Clang module.
@interface SentryHttpTransportWrapper : NSObject
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
                reachability:(SENTRY_SWIFT_MIGRATION_ID(SentryReachability))reachability;

+ (Class)httpTransportClass;
@end
NS_ASSUME_NONNULL_END
