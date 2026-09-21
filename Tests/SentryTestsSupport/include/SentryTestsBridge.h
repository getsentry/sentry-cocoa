#import <Foundation/Foundation.h>
@import _SentryPrivate;
#import "SentryANRTrackerV1.h"
#import "SentryANRTrackerV2.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryTraceContext.h"
#import "SentryTransportFactory.h"

NS_ASSUME_NONNULL_BEGIN

// Test-only, named categories expose selectors whose Swift-owned argument types are
// unavailable to a Clang module. The selectors and implementations remain in the SDK.
#if defined(__swift__)
#    if !SDK_V10
@interface SentryANRTrackerV1 (PackageTests)
- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
               applicationStateProvider:(id)applicationStateProvider
                   dispatchQueueWrapper:(id)dispatchQueueWrapper
                          threadWrapper:
                              (id)threadWrapper; // OK: Test bridge erases Swift-owned types.
@end
#        if SENTRY_HAS_UIKIT
@interface SentryANRTrackerV2 (PackageTests)
- (instancetype)initWithTimeoutInterval:(NSTimeInterval)timeoutInterval
               applicationStateProvider:(id)applicationStateProvider
                   dispatchQueueWrapper:(id)dispatchQueueWrapper
                          threadWrapper:(id)threadWrapper
                          framesTracker:
                              (id)framesTracker; // OK: Test bridge erases Swift-owned types.
@end
#        endif
#    endif

#    if SENTRY_HAS_UIKIT
@interface SentrySpanInternal (PackageTests)
- (instancetype)initWithContext:(SentrySpanContext *)context
                  framesTracker:(nullable id)framesTracker;
- (instancetype)initWithTracer:(SentryTracer *)tracer
                       context:(SentrySpanContext *)context
                 framesTracker:(nullable id)framesTracker;
@end
@interface SentryDelayedFramesTracker (PackageTests)
- (instancetype)
    initWithKeepDelayedFramesDuration:(CFTimeInterval)duration
                         dateProvider:(id)dateProvider; // OK: Test bridge erases Swift-owned types.
@end
#    endif

@interface SentryHubInternal (PackageTests)
- (instancetype)initWithClient:(nullable SentryClientInternal *)client
                      andScope:(nullable SentryScope *)scope
      activeCrashReporterState:(NSObject *)state
              andDispatchQueue:(id)queue; // OK: Test bridge erases Swift-owned types.
- (instancetype)initWithClient:(nullable SentryClientInternal *)client
                      andScope:(nullable SentryScope *)scope
      activeCrashReporterState:(NSObject *)state
          scopeContextEnricher:(id)enricher
              andDispatchQueue:(id)queue; // OK: Test bridge erases Swift-owned types.
@end

@interface SentryClientInternal (PackageTests)
- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(id)session
                      withScope:(SentryScope *)scope
    NS_SWIFT_NAME(captureFatalEvent(_:with:with:)); // OK: Test bridge erases Swift-owned types.
- (void)captureSession:(id)session
    NS_SWIFT_NAME(capture(session:)); // OK: Test bridge erases Swift-owned types.
- (void)captureFeedback:(id)feedback
              withScope:(SentryScope *)scope
    NS_SWIFT_NAME(capture(feedback:scope:)); // OK: Test bridge erases Swift-owned types.
- (void)storeEnvelope:(id)envelope
    NS_SWIFT_NAME(store(_:)); // OK: Test bridge erases Swift-owned types.
- (void)captureReplayEvent:(id)event
           replayRecording:(id)recording
                     video:(NSURL *)video
                 withScope:(SentryScope *)scope
    NS_SWIFT_NAME(capture(_:replayRecording:video:with:)); // OK: Test bridge erases Swift-owned types.
- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray *)items
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));
- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
                      hint:(nullable id)hint NS_SWIFT_NAME(capture(event:scope:hint:));
- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope
                      hint:(nullable id)hint NS_SWIFT_NAME(capture(error:scope:hint:));
- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope
                          hint:(nullable id)hint NS_SWIFT_NAME(capture(exception:scope:hint:));
- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope
                        hint:(nullable id)hint NS_SWIFT_NAME(capture(message:scope:hint:));
- (instancetype)initWithOptions:(NSObject *)options
                   dateProvider:(id)dateProvider
               transportAdapter:(id)transportAdapter
                    fileManager:(id)fileManager
                threadInspector:(id)threadInspector
             debugImageProvider:(id)debugImageProvider
                         random:(id)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           eventContextEnricher:(id)enricher
               binaryImageCache:(id)binaryImageCache
           dispatchQueueWrapper:(id)queue; // OK: Test bridge erases Swift-owned types.
@end

@interface SentryCrashStackEntryMapper (PackageTests)
- (instancetype)initWithInAppLogic:(id)inAppLogic; // OK: Test bridge erases Swift-owned types.
@end

@interface SentryEnvelopeRateLimit (PackageTests)
- (instancetype)initWithRateLimits:(NSObject *)rateLimits;
@end

@interface SentrySDKInternal (PackageTests)
+ (void)setStartOptions:(nullable id)options NS_SWIFT_NAME(setStart(with:));
+ (void)captureEnvelope:(id)envelope
    NS_SWIFT_NAME(capture(_:)); // OK: Test bridge erases Swift-owned types.
+ (void)storeEnvelope:(id)envelope
    NS_SWIFT_NAME(store(_:)); // OK: Test bridge erases Swift-owned types.
@end

@interface SentryScope (PackageTests)
- (void)applyToSession:(id)session
    NS_SWIFT_NAME(applyTo(session:)); // OK: Test bridge erases Swift-owned types.
@end

@interface SentryTraceContext (PackageTests)
- (nullable instancetype)initWithScope:(SentryScope *)scope
                               options:(id)options; // OK: Test bridge erases Swift-owned types.
- (nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)dictionary;
- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(id)options; // OK: Test bridge erases Swift-owned types.
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(id)options
                       replayId:(nullable NSString *)
                                    replayId; // OK: Test bridge erases Swift-owned types.
@end

@interface SentryTransactionContext (PackageTests)
- (instancetype)initWithName:(NSString *)name
                  nameSource:(NSInteger)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
    NS_SWIFT_NAME(init(name:testNameSource:operation:origin:));
- (instancetype)initWithName:(NSString *)name
                  nameSource:(NSInteger)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
    NS_SWIFT_NAME(init(name:testNameSource:operation:origin:sampled:sampleRate:sampleRand:));
- (instancetype)initWithName:(NSString *)name
                  nameSource:(NSInteger)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand
    NS_SWIFT_NAME(init(name:testNameSource:operation:origin:traceId:spanId:parentSpanId:parentSampled:parentSampleRate:parentSampleRand:));
- (instancetype)initWithName:(NSString *)name
                  nameSource:(NSInteger)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
                     sampled:(SentrySampleDecision)sampled
               parentSampled:(SentrySampleDecision)parentSampled
                  sampleRate:(nullable NSNumber *)sampleRate
            parentSampleRate:(nullable NSNumber *)parentSampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
            parentSampleRand:(nullable NSNumber *)parentSampleRand
    NS_SWIFT_NAME(init(name:testNameSource:operation:origin:traceId:spanId:parentSpanId:sampled:parentSampled:sampleRate:parentSampleRate:sampleRand:parentSampleRand:));
@end

#endif // defined(__swift__)

FOUNDATION_EXPORT NSObject *SentryTestClientFileManager(SentryClientInternal *client);
FOUNDATION_EXPORT void SentryTestSetClientFileManager(
    SentryClientInternal *client, NSObject *fileManager);
FOUNDATION_EXPORT NSObject *SentryTestClientOptions(SentryClientInternal *client);
FOUNDATION_EXPORT NSObject *_Nullable SentryTestHubSession(SentryHubInternal *hub);
FOUNDATION_EXPORT void SentryTestSetHubSession(SentryHubInternal *hub, NSObject *_Nullable session);
FOUNDATION_EXPORT NSObject *_Nullable SentryTestSDKOptions(void);
FOUNDATION_EXPORT NSObject *SentryTestScopePropagationContext(SentryScope *scope);
FOUNDATION_EXPORT void SentryTestSetScopePropagationContext(SentryScope *scope, NSObject *context);
FOUNDATION_EXPORT NSDictionary *SentryTestTracerMeasurements(SentryTracer *tracer);
FOUNDATION_EXPORT NSInteger SentryTestTransactionNameSource(SentryTransactionContext *context);
#if !SDK_V10
FOUNDATION_EXPORT NSObject *SentryTestCrashScopeObserver(NSInteger maxBreadcrumbs);
#endif
FOUNDATION_EXPORT NSArray *SentryTestInstalledIntegrations(SentryHubInternal *hub);

FOUNDATION_EXPORT id SentryTestMakeHttpTransport(id dsn, BOOL sendClientReports,
    NSTimeInterval cachedEnvelopeSendDelay, id dateProvider, id fileManager, id requestManager,
    id requestBuilder, id rateLimits, SentryEnvelopeRateLimit *envelopeRateLimit,
    id dispatchQueueWrapper, id reachability);
FOUNDATION_EXPORT BOOL SentryTestIsHttpTransport(id transport);
FOUNDATION_EXPORT NSArray *SentryTestInitTransports(
    id options, id dateProvider, id fileManager, id rateLimits, id reachability);
FOUNDATION_EXPORT SentryEnvelopeRateLimit *SentryTestMakeEnvelopeRateLimit(id rateLimits);
FOUNDATION_EXPORT id SentryTestRemoveRateLimitedItems(
    SentryEnvelopeRateLimit *rateLimit, id envelope);

@interface SentryTestSessionDelegateBridge : NSObject <SentrySessionDelegate>
@property (nonatomic, copy) id _Nullable (^handler)(void)
    ; // OK: Test callback returns a Swift-owned session.
@end

@interface SentryTestEnvelopeRateLimitDelegate : NSObject <SentryEnvelopeRateLimitDelegate>
- (void)envelopeItemDropped:(id)item
                rawCategory:
                    (NSUInteger)category; // OK: Test bridge erases a Swift-owned envelope item.
@end

NS_ASSUME_NONNULL_END
