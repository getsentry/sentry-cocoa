#import "SentryDefines.h"
#import "SentryScope.h"
#import "SentrySpanInternal.h"
#import "SentryTraceContext.h"
#import "SentryTransactionContext.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Declare the SDK's existing selectors with module-safe types and distinct Swift names.
// These categories add no implementations: calls still dispatch to the real SDK objects.
@interface SentryClientInternal (TestAccess)
- (SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager NS_SWIFT_NAME(test_fileManager());
- (void)setFileManager:(SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager
    NS_SWIFT_NAME(test_setFileManager(_:));
- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
                      withScope:(SentryScope *)scope
    NS_SWIFT_NAME(test_captureFatalEvent(_:session:scope:));

- (void)captureSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(capture(session:));
- (void)captureFeedback:(SENTRY_SWIFT_MIGRATION_ID(SentryFeedback))feedback
              withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(feedback:scope:));
- (void)captureReplayEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayEvent))event
           replayRecording:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayRecording))recording
                     video:(NSURL *)video
                 withScope:(SentryScope *)scope
    NS_SWIFT_NAME(test_captureReplayEvent(_:recording:video:scope:));
- (void)storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(test_storeEnvelope(_:));

- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
                      hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(event:scope:hint:));
- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope
                      hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(error:scope:hint:));
- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope
                          hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(exception:scope:hint:));
- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope
                        hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(message:scope:hint:));
- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray *)items
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));
@end

@interface SentryHubInternal (TestAccess)
- (nullable SENTRY_SWIFT_MIGRATION_ID(SentrySession))session NS_SWIFT_NAME(test_session());
- (void)setSession:(nullable SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(test_setSession(_:));
@end

@interface SentryTransactionContext (TestAccess)
- (SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))nameSource NS_SWIFT_NAME(test_nameSource());

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:));

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:sampled:sampleRate:sampleRand:));

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:trace:spanId:parentSpanId:parentSampled:parentSampleRate:parentSampleRand:));

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
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
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:trace:spanId:parentSpanId:sampled:parentSampled:sampleRate:parentSampleRate:sampleRand:parentSampleRand:));
@end

@interface SentryScope (TestAccess)
#if SWIFT_PACKAGE
- (SENTRY_SWIFT_MIGRATION_ID(SentryPropagationContext))propagationContext NS_SWIFT_NAME(test_propagationContext());
- (void)setPropagationContext:(SENTRY_SWIFT_MIGRATION_ID(SentryPropagationContext))context
    NS_SWIFT_NAME(test_setPropagationContext(_:));
#endif
- (void)applyToSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(applyTo(session:));
@end

@interface SentryTraceContext (TestAccess)
- (nullable instancetype)initWithScope:(SentryScope *)scope
                               options:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
    NS_SWIFT_NAME(init(testScope:testOptions:));
- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
    NS_SWIFT_NAME(init(testTracer:scope:testOptions:));
- (instancetype)initWithTraceId:(SentryId *)traceId
                        options:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
                       replayId:(nullable NSString *)replayId
    NS_SWIFT_NAME(init(testTrace:testOptions:replayId:));
@end

// Xcode already imports this initializer with its Swift-defined parameter. Redeclaring it
// there with a different Swift name creates duplicate inherited initializers in Swift subclasses.
#if SENTRY_HAS_UIKIT && SWIFT_PACKAGE
@interface SentrySpanInternal (TestAccess)
- (instancetype)initWithContext:(SentrySpanContext *)context
                  framesTracker:
                      (nullable SENTRY_SWIFT_MIGRATION_ID(SentryFramesTracker))framesTracker
    NS_SWIFT_NAME(init(testContext:testFramesTracker:));
@end
#endif

@interface SentryTracer (TestAccess)
- (NSDictionary *)measurements NS_SWIFT_NAME(test_measurements());
@end

@interface SentrySDKInternal (TestAccess)
+ (nullable SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options NS_SWIFT_NAME(test_options());
@end

NS_ASSUME_NONNULL_END
