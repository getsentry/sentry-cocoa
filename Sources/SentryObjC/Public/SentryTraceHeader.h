#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySampleDecision.h"

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_TRACE_HEADER = @"sentry-trace";

/**
 * Trace information for the sentry-trace HTTP header.
 *
 * @see SentrySpan
 */
@interface SentryTraceHeader : NSObject

SENTRY_NO_INIT

/** Trace ID. */
@property (nonatomic, readonly) SentryId *traceId;

/** Span ID. */
@property (nonatomic, readonly) SentrySpanId *spanId;

/** The trace sample decision. */
@property (nonatomic, readonly) SentrySampleDecision sampled;

/** Creates a trace header with the given values. */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                        sampled:(SentrySampleDecision)sampled;

/** Returns the value to use in a request header. */
- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
