#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCSampleDecision.h"
#else
#    import <SentryObjC/SentryObjCSampleDecision.h>
#endif

@class SentryObjCId;
@class SentryObjCSpanId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Span context that represents the data of a span that is being started.
 * Contains trace, span, and parent identifiers, the operation name, and the sampling decision.
 */
@interface SentryObjCSpanContext : NSObject

/// Determines which trace the span belongs to.
@property (nonatomic, readonly, strong) SentryObjCId *traceId;

/// The span id.
@property (nonatomic, readonly, strong) SentryObjCSpanId *spanId;

/// Id of a parent span.
@property (nonatomic, readonly, strong, nullable) SentryObjCSpanId *parentSpanId;

/// If the trace is sampled.
@property (nonatomic, readonly) SentryObjCSampleDecision sampled;

/// Short code identifying the type of operation the span is measuring.
@property (nonatomic, readonly, copy) NSString *operation;

/**
 * Longer description of the span's operation, which uniquely identifies the span but is
 * consistent across instances of the span.
 */
@property (nonatomic, readonly, copy, nullable) NSString *spanDescription;

/**
 * The origin of the span indicates what created the span.
 * @note Gets set by the SDK. It is not expected to be set manually by users.
 * @see https://develop.sentry.dev/sdk/performance/trace-origin
 */
@property (nonatomic, copy) NSString *origin;

/**
 * Init a span context with an operation code.
 * @note @c traceId and @c spanId will be randomly created; @c sampled by default is
 * @c SentryObjCSampleDecisionUndecided.
 * @param operation The operation this span is measuring.
 */
- (instancetype)initWithOperation:(NSString *)operation;

/**
 * Init a span context with an operation code and mark it as sampled or not.
 * @c traceId and @c spanId will be randomly created.
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithOperation:(NSString *)operation sampled:(SentryObjCSampleDecision)sampled;

/**
 * @param traceId Determines which trace the span belongs to.
 * @param spanId The span id.
 * @param parentId Id of a parent span.
 * @param operation The operation this span is measuring.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithTraceId:(SentryObjCId *)traceId
                         spanId:(SentryObjCSpanId *)spanId
                       parentId:(nullable SentryObjCSpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentryObjCSampleDecision)sampled;

/**
 * @param traceId Determines which trace the span belongs to.
 * @param spanId The span id.
 * @param parentId Id of a parent span.
 * @param operation The operation this span is measuring.
 * @param description The span description.
 * @param sampled Determines whether the trace should be sampled.
 */
- (instancetype)initWithTraceId:(SentryObjCId *)traceId
                         spanId:(SentryObjCSpanId *)spanId
                       parentId:(nullable SentryObjCSpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentryObjCSampleDecision)sampled;

@end

NS_ASSUME_NONNULL_END
