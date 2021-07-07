#import <Foundation/Foundation.h>
#import "SentrySampleDecision.h"

@class SentryId, SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_TRACE_HEADER = @"sentry-trace";

@interface SentryTraceHeader : NSObject

/**
 * Trace ID.
 */
@property (nonatomic, readonly) SentryId *traceId;

/**
 * Span ID.
 */
@property (nonatomic, readonly) SentrySpanId *spanId;

/**
 * The trace sample decision.
 */
@property (nonatomic, readonly) SentrySampleDecision sampleDecision;


/**
 * Initialize a SentryTraceHeader with given trace id, span id and sample decision.
 *
 * @param traceId The trace id.
 * @param spanId The span id.
 * @param sampleDecision The decision made to sample the trace related to this header.
 *
 * @return A SentryTraceHeader.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                 sampleDecision:(SentrySampleDecision)sampleDecision;


/**
 * Return the value to use in a request header.
 */
- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
