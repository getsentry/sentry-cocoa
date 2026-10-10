#import "SentryDefines.h"
#import <Foundation/Foundation.h>
@import _SentryPrivate;

#import "../../../Sources/Sentry/include/SentryEnvelopeRateLimit.h"

NS_ASSUME_NONNULL_BEGIN

// Implement callbacks involving Swift-owned types in ObjC and expose erased override seams
// to Swift subclasses. Declare conformance here so tests can use the SDK's original setters.
@interface SentryTestEnvelopeRateLimitDelegateWrapper : NSObject <SentryEnvelopeRateLimitDelegate>
- (void)wrapper_envelopeItemDropped:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelopeItem))envelopeItem
                       withCategory:(NSUInteger)category;
@end

@interface SentryTestSessionDelegateWrapper : NSObject <SentrySessionDelegate>
- (nullable SENTRY_SWIFT_MIGRATION_ID(SentrySession))wrapper_incrementSessionErrors;
@end

// HTTP transport's header imports the generated Swift interface, so construct it in ObjC.
// SentrySDKTestAdapters.swift restores the return type without exposing that interface here.
@interface SentryTestSDKBridge : NSObject
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
