
#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#    import <Sentry/SentrySampleDecision.h>
#    import <Sentry/SentrySerializable.h>
#    import <Sentry/SentrySpanStatus.h>
#else
#    import <SentryWithoutUIKit/SentryDefines.h>
#    import <SentryWithoutUIKit/SentrySampleDecision.h>
#    import <SentryWithoutUIKit/SentrySerializable.h>
#    import <SentryWithoutUIKit/SentrySpanStatus.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SentryId;
@class SentrySpanId;

static NSString const *SENTRY_TRACE_TYPE = @"trace";

NS_SWIFT_NAME(SpanContext)
@interface SentrySpanContext : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Determines which trace the Span belongs to.
 */
@property (nonatomic, readonly) SentryId *traceId;

/**
 * Span id.
 */
@property (nonatomic, readonly) SentrySpanId *spanId;

/**
 * Id of a parent span.
 */
@property (nullable, nonatomic, readonly) SentrySpanId *parentSpanId;

/**
 * If trace is sampled.
 */
@property (nonatomic, readonly) SentrySampleDecision sampled;

/**
 * Rate of sampling
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *sampleRate;

/**
 * Random value used to determine if the span is sampled.
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *sampleRand;

/**
 * Short code identifying the type of operation the span is measuring.
 */
@property (nonatomic, copy, readonly) NSString *operation;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nullable, nonatomic, copy, readonly) NSString *spanDescription;

/**
 * The origin of the span indicates what created the span.
 *
 * @note Gets set by the SDK. It is not expected to be set manually by users. Although the protocol
 * allows this value to be optional, we make it nonnullable as we always send the value.
 *
 * @see <https://develop.sentry.dev/sdk/performance/trace-origin>
 */
@property (nonatomic, copy) NSString *origin;

/**
 * Init a @c SentryContext with an operation code.
 * @note @c traceId and @c spanId with be randomly created; @c sampled by default is
 * @c kSentrySampleDecisionUndecided .
 */
- (instancetype)initWithOperation:(NSString *)operation;

/**
 * Init a @c SentryContext with an operation code and mark it as sampled or not.
 * TraceId and SpanId with be randomly created.
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithOperation:(NSString *)operation sampled:(SentrySampleDecision)sampled;

/**
 * Init a @c SentryContext with an operation code and mark it as sampled or not.
 * TraceId and SpanId with be randomly created.
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 * @param sampleRate Rate of sampling
 * @param sampleRand Random value used to determine if the trace is sampled.
 */
- (instancetype)initWithOperation:(NSString *)operation
                          sampled:(SentrySampleDecision)sampled
                       sampleRate:(nullable NSNumber *)sampleRate
                       sampleRand:(nullable NSNumber *)sampleRand;

/**
 * @param traceId Determines which trace the Span belongs to.
 * @param spanId The Span Id.
 * @param operation The operation this span is measuring.
 * @param parentId Id of a parent span.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled;

/**
 * @param traceId Determines which trace the Span belongs to.
 * @param spanId The Span Id.
 * @param operation The operation this span is measuring.
 * @param parentId Id of a parent span.
 * @param sampled Determines whether the trace should be sampled.
 * @param sampleRate Rate of sampling
 * @param sampleRand Random value used to determine if the trace is sampled.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled
                     sampleRate:(nullable NSNumber *)sampleRate
                     sampleRand:(nullable NSNumber *)sampleRand;

/**
 * @param traceId Determines which trace the Span belongs to.
 * @param spanId The Span Id.
 * @param operation The operation this span is measuring.
 * @param parentId Id of a parent span.
 * @param description The span description.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled;

/**
 * @param traceId Determines which trace the Span belongs to.
 * @param spanId The Span Id.
 * @param operation The operation this span is measuring.
 * @param parentId Id of a parent span.
 * @param description The span description.
 * @param sampled Determines whether the trace should be sampled.
 * @param sampleRate Rate of sampling
 * @param sampleRand Random value used to determine if the trace is sampled.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled
                     sampleRate:(nullable NSNumber *)sampleRate
                     sampleRand:(nullable NSNumber *)sampleRand;

@end

NS_ASSUME_NONNULL_END
