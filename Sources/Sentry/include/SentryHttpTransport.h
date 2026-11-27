#import "SentryDefines.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentrySwift.h"

@class SentryFileManager;
@class SentryDispatchQueueWrapper;
@class SentryNSURLRequestBuilder;
@class SentryDsn;
@class SentryFileManager;
@class SentryReachability;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;
@protocol SentryRequestManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport : NSObject <SentryTransport, SentryEnvelopeRateLimitDelegate>
SENTRY_NO_INIT

- (id)initWithDsn:(SentryDsn *)dsn
          sendClientReports:(BOOL)sendClientReports
    cachedEnvelopeSendDelay:(NSTimeInterval)cachedEnvelopeSendDelay
               dateProvider:(id<SentryCurrentDateProvider>)dateProvider
                fileManager:(SentryFileManager *)fileManager
             requestManager:(id<SentryRequestManager>)requestManager
             requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
                 rateLimits:(id<SentryRateLimits>)rateLimits
          envelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
       dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
               reachability:(SentryReachability *)reachability;

#if defined(DEBUG) // Test support.
/**
 * Runs on the thread that called @c flush:, after it stops waiting and before it cleans up, so a
 * test can order another flush between the two.
 */
- (void)setFlushWaitFinishedCallback:(nullable void (^)(void))callback;
#endif // defined(DEBUG)

@end

NS_ASSUME_NONNULL_END
