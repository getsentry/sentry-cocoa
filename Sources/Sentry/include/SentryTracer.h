#import "SentrySpanProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryHub, SentryTransactionContext, SentryTraceHeader;

@interface SentryTracer : NSObject <SentrySpan>

/**
 *Span name.
 */
@property (nonatomic, copy) NSString *name;

/**
 * The context information of the span.
 */
@property (nonatomic, readonly) SentrySpanContext *context;

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
@property (nullable, readonly) NSDictionary<NSString *, id> *data;

/**
 * Whether the span is finished.
 */
@property (readonly) BOOL isFinished;

/**
 * Indicates whether this tracer will be finished only if all children have been finished.
 * If this property is YES and the finish function is called before all children are finished
 * the tracer will automatically finish when the last child finishes.
 */
@property (readonly) BOOL waitForChildren;

/**
 * Init a SentryTracer with given transaction context and hub and set other fields by default
 *
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 *
 * @return SentryTracer
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub;
/**
 * Init a SentryTracer with given transaction context, hub and whether the tracer should wait
 * for all children to finish before it finishes.
 *
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 * @param waitForChildren Whether this tracer should wait all children to finish.
 *
 * @return SentryTracer
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                           waitForChildren:(BOOL)waitForChildren;

/**
 * Starts a child span.
 *
 * @param operation Short code identifying the type of operation the span is measuring.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
    NS_SWIFT_NAME(startChild(operation:));

/**
 * Starts a child span.
 *
 * @param operation Defines the child span operation.
 * @param description Define the child span description.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithOperation:(NSString *)operation
                              description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(operation:description:));

/**
 * Starts a child span.
 *
 * @param parentId The child span parent id.
 * @param operation The child span operation.
 * @param description The child span description.
 *
 * @return SentrySpan
 */
- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(parentId:operation:description:));

/**
 * Sets an extra.
 */
- (void)setDataValue:(nullable id)value
              forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Finishes the transaction by setting the end time and capturing the transaction with binded hub.
 */
- (void)finish;

/**
 * Finishes the span by setting the end time and span status.
 *
 * @param status The status of this span
 */
- (void)finishWithStatus:(SentrySpanStatus)status NS_SWIFT_NAME(finish(status:));

/**
 * Returns a string that could be sent as a sentry-trace header.
 *
 * @return SentryTraceHeader.
 */
- (SentryTraceHeader *)toTraceHeader;
@end

NS_ASSUME_NONNULL_END
