#import "SentrySpan.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol used to intercept some of `SentryTracer` steps
 * in order to modify its behavior and distribute concern to other classes.
 */
@protocol SentryTracerMiddleware <NSObject>

@optional

/**
 * Called when the middleware is attached to a SentryTracer
 */
- (void)installForTracer:(SentryTracer *)tracer;

/**
 * Called when the middleware is removed from a SentryTracer
 */
- (void)uninstallForTracer:(SentryTracer *)tracer;

/**
 Return additional spans to be added to the transaction.
 */
- (NSArray<id<SentrySpan>> *)createAdditionalSpansForTrace:(SentryTracer *)tracer;

/**
 Called when the dead line timeout is triggered
 */
- (void)tracerDidTimeout:(SentryTracer *)tracer;

/**
 * Called when the `SentryTracer` is finished.
 */
- (void)tracerDidFinish:(SentryTracer *)tracer;

@end

NS_ASSUME_NONNULL_END
