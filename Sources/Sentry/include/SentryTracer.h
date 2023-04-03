#import "SentrySpan.h"
#import "SentrySpanProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryHub, SentryTransactionContext, SentryTraceHeader, SentryTraceContext,
    SentryNSTimerWrapper, SentryDispatchQueueWrapper, SentryTracer, SentryProfilesSamplerDecision,
    SentryMeasurementValue;

static NSTimeInterval const SentryTracerDefaultTimeout = 3.0;

@protocol SentryTracerDelegate

/**
 * Return the active span of given tracer.
 * This function is used to determine which span will be used to create a new child.
 */
- (nullable id<SentrySpan>)activeSpanForTracer:(SentryTracer *)tracer;

/**
 * Report that the tracer has finished.
 */
- (void)tracerDidFinish:(SentryTracer *)tracer;

@end

@interface SentryTracer : SentrySpan

@property (nonatomic, strong) SentryTransactionContext *transactionContext;

@property (nullable, nonatomic, copy) void (^finishCallback)(SentryTracer *);

/**
 * Indicates whether this tracer will be finished only if all children have been finished.
 * If this property is @c YES and the finish function is called before all children are finished
 * the tracer will automatically finish when the last child finishes.
 */
@property (readonly) BOOL waitForChildren;

/**
 * Retrieves a trace context from this tracer.
 */
@property (nonatomic, readonly) SentryTraceContext *traceContext;

/**
 * All the spans that where created with this tracer but rootSpan.
 */
@property (nonatomic, readonly) NSArray<id<SentrySpan>> *children;

/**
 * A delegate that provides extra information for the transaction.
 */
@property (nullable, nonatomic, weak) id<SentryTracerDelegate> delegate;

@property (nonatomic, readonly) NSDictionary<NSString *, SentryMeasurementValue *> *measurements;

/**
 * When an app launch is traced, after building the app start spans, the tracer's start timestamp is
 * adjusted backwards to be the start of the first app start span. But, we still need to know the
 * real start time of the trace for other purposes. This property provides a place to keep it before
 * reassigning it.
 */
@property (strong, nonatomic, readonly) NSDate *originalStartTimestamp;

/**
 * Init a @c SentryTracer with given transaction context and hub and set other fields by default
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub;

/**
 * Init a @c SentryTracer with given transaction context, hub and whether the tracer should wait
 * for all children to finish before it finishes.
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 * @param waitForChildren Whether this tracer should wait all children to finish.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                           waitForChildren:(BOOL)waitForChildren;

/**
 * Init a @c SentryTracer with given transaction context, hub and whether the tracer should wait
 * for all children to finish before it finishes.
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction.
 * @param profilesSamplerDecision Whether to sample a profile corresponding to this transaction.
 * @param waitForChildren Whether this tracer should wait all children to finish.
 * @param timerWrapper A wrapper around @c NSTimer, to make it testable.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                   profilesSamplerDecision:
                       (nullable SentryProfilesSamplerDecision *)profilesSamplerDecision
                           waitForChildren:(BOOL)waitForChildren
                              timerWrapper:(nullable SentryNSTimerWrapper *)timerWrapper;

/**
 * Init a @c SentryTracer with given transaction context, hub and whether the tracer should wait
 * for all children to finish before it finishes.
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 * @param profilesSamplerDecision Whether to sample a profile corresponding to this transaction
 * @param idleTimeout The idle time to wait until to finish the transaction.
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                   profilesSamplerDecision:
                       (nullable SentryProfilesSamplerDecision *)profilesSamplerDecision
                               idleTimeout:(NSTimeInterval)idleTimeout
                      dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(parentId:operation:description:));

/**
 * A method to inform the tracer that a span finished.
 */
- (void)spanFinished:(id<SentrySpan>)finishedSpan;

/**
 * Get the tracer from a span.
 */
+ (nullable SentryTracer *)getTracer:(id<SentrySpan>)span;

- (void)dispatchIdleTimeout;

@end

NS_ASSUME_NONNULL_END
