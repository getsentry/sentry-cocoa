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

/** Initializes with an operation code. traceId and spanId are randomly created. */
- (instancetype)initWithOperation:(NSString *)operation;

/** Initializes with operation and sampled flag. */
- (instancetype)initWithOperation:(NSString *)operation sampled:(SentrySampleDecision)sampled;

/** Full initializer. */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                        sampled:(SentrySampleDecision)sampled;

/** Full initializer with span description. */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                      operation:(NSString *)operation
                spanDescription:(nullable NSString *)description
                        sampled:(SentrySampleDecision)sampled;

@end

NS_ASSUME_NONNULL_END
