#import <Foundation/Foundation.h>
#if SWIFT_PACKAGE
#    import "SentryObjCSampleDecision.h"
#else
#    import <SentryObjC/SentryObjCSampleDecision.h>
#endif

@class SentryObjCId;
@class SentryObjCSpanId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the @c sentry-trace HTTP header value used for distributed tracing.
 * Contains the trace id, span id, and sampling decision.
 */
@interface SentryObjCTraceHeader : NSObject

/// The trace ID.
@property (nonatomic, readonly, strong) SentryObjCId *traceId;

/// The span ID.
@property (nonatomic, readonly, strong) SentryObjCSpanId *spanId;

/// The trace sample decision.
@property (nonatomic, readonly) SentryObjCSampleDecision sampled;

/**
 * @param traceId The trace id.
 * @param spanId The span id.
 * @param sampled The decision made to sample the trace related to this header.
 */
- (instancetype)initWithTraceId:(SentryObjCId *)traceId
                         spanId:(SentryObjCSpanId *)spanId
                        sampled:(SentryObjCSampleDecision)sampled;

/// Returns the value to use in a request header.
- (NSString *)value;

@end

NS_ASSUME_NONNULL_END
