#import "SentrySpanContext.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryTransaction, SentrySpanId, SentryId, SentryHub;

NS_SWIFT_NAME(Span)
@interface SentrySpan : SentrySpanContext
SENTRY_NO_INIT

/**
 * The timestamp of which the span ended.
 */
@property (nullable, nonatomic, strong) NSDate *timestamp;

/**
 * The start time of the span.
 */
@property (nullable, nonatomic, strong) NSDate *startTimestamp;

/**
 * An arbitrary mapping of additional metadata of the span.
 */
@property (nullable, readonly) NSDictionary<NSString *, id> *extras;

/**
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * Init a SentrySpan with given transaction, traceId, parentSpanId and hub.
 *
 * @param transaction The transaction associated with this span.
 * @param traceId Determines which trace the Span belongs to.
 * @param parentId Id of a parent span.
 *
 * @return SentrySpan
 */
- (instancetype)initWithTransaction:(SentryTransaction *)transaction
                            traceId:(SentryId *)traceId
                           parentId:(SentrySpanId *)parentId;

/*
 Removed because SentrySpan requires a transaction
 */
- (instancetype)initWithSampled:(BOOL)sampled NS_UNAVAILABLE;

/*
 Removed because SentrySpan requires a transaction
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                         spanId:(SentrySpanId *)spanId
                       parentId:(nullable SentrySpanId *)parentId
                        sampled:(BOOL)sampled NS_UNAVAILABLE;

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 *
 * @return SentrySpan
 */
- (SentrySpan *)startChildWithOperation:(NSString *)operation NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (SentrySpan *)startChildWithOperation:(NSString *)operation
                            description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

/**
 * Sets an extra.
 */
- (void)setExtraValue:(id _Nullable)value
               forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Finishes the span by setting the end time.
 */
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 *
 * @param status The status of this span
 *  */
- (void)finishWithStatus:(SentrySpanStatus)status NS_SWIFT_NAME(finish(status:));

@end

NS_ASSUME_NONNULL_END
