#import "SentrySpan.h"
#import "SentrySpanProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryHub, SentryTransactionContext, SentryTraceHeader, SentryTraceContext,
    SentryNSTimerWrapper, SentryDispatchQueueWrapper, SentryTracer, SentryProfilesSamplerDecision,
    SentryMeasurementValue;

static NSTimeInterval const SentryTracerDefaultTimeout = 3.0;

typedef struct {
    /**
     * Indicates whether the tracer will be finished only if all children have been finished.
     * If this property is YES and the finish function is called before all children are finished
     * the tracer will automatically finish when the last child finishes.
     *
     * Default is NO.
     */
    BOOL waitForChildren;

    /**
     * A dispatch queue wrapper to intermediate between the tracer and dispatch calls.
     */
    SentryDispatchQueueWrapper * _Nullable dispatchQueueWrapper;

    /**
     * Whether to sample a profile corresponding to this transaction
     */
    SentryProfilesSamplerDecision * _Nullable  profilesSamplerDecision;

    /**
     * The idle time to wait until to finish the transaction
     *
     * Default is 0 seconds
     */
    NSTimeInterval idleTimeout;

    /**
     * A writer around NSTimer, to make it testable
     */
    SentryNSTimerWrapper * _Nullable timerWrapper;

    /**
     * Indicates whether the tracer should automatically capture the transaction after finishing.
     *
     * Default is YES.
     */
    BOOL autoCapture;

} SentryTracerConfiguration;

typedef void (^SentryTracerConfigure)(SentryTracerConfiguration* configuration);

@protocol SentryTracerDelegate

/**
 * Return the active span of given tracer.
 * This function is used to determine which span will be used to create a new child.
 */
- (nullable id<SentrySpan>)activeSpanForTracer:(SentryTracer *)tracer;

@end

@interface SentryTracer : SentrySpan

@property (nonatomic, strong) SentryTransactionContext *transactionContext;

@property (nullable, nonatomic, copy) void (^finishCallback)(SentryTracer *);

/**
 * Retrieves a trace context from this tracer.
 */
@property (nonatomic, readonly) SentryTraceContext *traceContext;

/*
 All the spans that where created with this tracer but rootSpan.
 */
@property (nonatomic, readonly) NSArray<id<SentrySpan>> *children;

/*
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
 * Init a SentryTracer with given transaction context and hub and set other fields by default
 *
 * @param transactionContext Transaction context
 * @param hub A hub to bind this transaction
 *
 * @return SentryTracer
 */
- (instancetype)initWithTransactionContext:(SentryTransactionContext *)transactionContext
                                       hub:(nullable SentryHub *)hub
                                 configure:(nullable SentryTracerConfigure)configure;

- (id<SentrySpan>)startChildWithParentId:(SentrySpanId *)parentId
                               operation:(NSString *)operation
                             description:(nullable NSString *)description
    NS_SWIFT_NAME(startChild(parentId:operation:description:));

/**
 * A method to inform the tracer that a span finished.
 */
- (void)spanFinished:(id<SentrySpan>)finishedSpan;


/**
 * Capture the transaction in case it was not captured yet.
 */
- (void)capture;


/**
 * Get the tracer from a span.
 */
+ (nullable SentryTracer *)getTracer:(id<SentrySpan>)span;

- (void)dispatchIdleTimeout;

@end

NS_ASSUME_NONNULL_END
