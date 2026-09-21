#import "SentryTestsBridge.h"
#import "SentryCrashScopeHelper.h"
#import "SentryHttpTransport.h"
#import "SentryHub+Test.h"
#import "SentrySwift.h"

NSObject *
SentryTestClientFileManager(SentryClientInternal *client)
{
    return client.fileManager;
}
void
SentryTestSetClientFileManager(SentryClientInternal *client, NSObject *fileManager)
{
    client.fileManager = (SentryFileManager *)fileManager;
}
NSObject *
SentryTestClientOptions(SentryClientInternal *client)
{
    return client.options;
}
NSObject *
SentryTestHubSession(SentryHubInternal *hub)
{
    return hub.session;
}
void
SentryTestSetHubSession(SentryHubInternal *hub, NSObject *session)
{
    hub.session = (SentrySession *)session;
}
NSObject *
SentryTestSDKOptions(void)
{
    return [SentrySDKInternal options];
}
NSObject *
SentryTestScopePropagationContext(SentryScope *scope)
{
    return scope.propagationContext;
}
void
SentryTestSetScopePropagationContext(SentryScope *scope, NSObject *context)
{
    scope.propagationContext = (SentryPropagationContext *)context;
}
NSDictionary *
SentryTestTracerMeasurements(SentryTracer *tracer)
{
    return tracer.measurements;
}
NSInteger
SentryTestTransactionNameSource(SentryTransactionContext *context)
{
    return context.nameSource;
}
#if !SDK_V10
NSObject *
SentryTestCrashScopeObserver(NSInteger maxBreadcrumbs)
{
    return (NSObject *)[SentryCrashScopeHelper getScopeObserverWithMaxBreacdrumb:maxBreadcrumbs];
}
#endif
NSArray *
SentryTestInstalledIntegrations(SentryHubInternal *hub)
{
    return [hub installedIntegrations];
}

id
SentryTestMakeHttpTransport(id dsn, BOOL sendClientReports, NSTimeInterval cachedEnvelopeSendDelay,
    id dateProvider, id fileManager, id requestManager, id requestBuilder, id rateLimits,
    SentryEnvelopeRateLimit *envelopeRateLimit, id dispatchQueueWrapper, id reachability)
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
BOOL
SentryTestIsHttpTransport(id transport)
{
    return [transport isKindOfClass:SentryHttpTransport.class];
}
NSArray *
SentryTestInitTransports(
    id options, id dateProvider, id fileManager, id rateLimits, id reachability)
{
    return [SentryTransportFactory initTransports:options
                                     dateProvider:dateProvider
                                sentryFileManager:fileManager
                                       rateLimits:rateLimits
                                     reachability:reachability];
}
SentryEnvelopeRateLimit *
SentryTestMakeEnvelopeRateLimit(id rateLimits)
{
    return [[SentryEnvelopeRateLimit alloc] initWithRateLimits:rateLimits];
}
id
SentryTestRemoveRateLimitedItems(SentryEnvelopeRateLimit *rateLimit, id envelope)
{
    return [rateLimit removeRateLimitedItems:envelope];
}

@implementation SentryTestSessionDelegateBridge
- (SentrySession *)incrementSessionErrors
{
    return self.handler();
}
@end

@implementation SentryTestEnvelopeRateLimitDelegate
- (void)envelopeItemDropped:(SentryEnvelopeItem *)item withCategory:(SentryDataCategory)category
{
    [self envelopeItemDropped:item rawCategory:category];
}
- (void)envelopeItemDropped:(id)item rawCategory:(NSUInteger)category
{
    // Overridden by the Swift spy.
}
@end
