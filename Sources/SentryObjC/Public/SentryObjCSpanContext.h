#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSampleDecision.h"
#import "SentryObjCSerializable.h"

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

static NSString const *SENTRY_TRACE_TYPE = @"trace";

/**
 * Context identifying a span within a trace.
 *
 * @see SentrySpan
 * @see SentryTransactionContext
 */
@interface SentrySpanContext : NSObject <SentrySerializable>

SENTRY_NO_INIT

/** Determines which trace the Span belongs to. */
@property (nonatomic, readonly) SentryId *traceId;

/** Span id. */
@property (nonatomic, readonly) SentrySpanId *spanId;

/** Id of a parent span. */
@property (nullable, nonatomic, readonly) SentrySpanId *parentSpanId;

/** Whether the trace is sampled. */
@property (nonatomic, readonly) SentrySampleDecision sampled;

/** Short code identifying the type of operation the span is measuring. */
@property (nonatomic, copy, readonly) NSString *operation;

/** Longer description of the span's operation. */
@property (nullable, nonatomic, copy, readonly) NSString *spanDescription;

/**
 * The origin of the span indicates what created the span.
 *
 * @note Set by the SDK. Not expected to be set manually.
 * @see https://develop.sentry.dev/sdk/performance/trace-origin
 */
@property (nonatomic, copy) NSString *origin;

/**
 * Creates a span context with an operation.
 *
 * Trace ID and span ID are randomly generated.
 *
 * @param operation The operation type.
 * @return A new span context instance.
 */
- (instancetype)initWithOperation:(NSString *)operation;

/**
 * Creates a span context with operation and sampling decision.
 *
 * @param operation The operation type.
 * @param sampled Whether this span is sampled.
 * @return A new span context instance.
 */
- (instancetype)initWithOperation:(NSString *)operation sampled:(SentrySampleDecision)sampled;

/**
 * Creates a span context with full trace information.
 *
 * @param traceId The trace ID.
 * @param spanId The span ID.
 * @param parentId The parent span ID, or @c nil for root spans.
 * @param operation The operation type.
 * @param sampled Whether this span is sampled.
 * @return A new span context instance.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled;

/**
 * Creates a span context with full trace information and description.
 *
 * @param traceId The trace ID.
 * @param spanId The span ID.
 * @param parentId The parent span ID, or @c nil for root spans.
 * @param operation The operation type.
 * @param description Human-readable description of the span.
 * @param sampled Whether this span is sampled.
 * @return A new span context instance.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled;

@end

NS_ASSUME_NONNULL_END
