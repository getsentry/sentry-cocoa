#import "SentrySpan.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

typedef SentrySpan *_Nonnull (^SpanCreationCallback)(NSString *operation, NSString *description);

/**
 * Protocol used to intercept some of `SentryTracer` steps
 * in order to modify its behavior and distribute concern to other classes.
 */
@protocol SentryTracerExtension <NSObject>

/**
 * Called when the extension is attached to a SentryTracer.
 * You should no keep a strong reference to the tracer.
 */
- (void)installForTracer:(SentryTracer *)tracer;

/**
 Return additional spans to be added to the transaction.
 */
- (NSArray<id<SentrySpan>> *)tracerAdditionalSpan:(SpanCreationCallback)creationCallback;

/**
 Called when the dead line timeout is triggered
 */
- (void)tracerDidTimeout;

@end

NS_ASSUME_NONNULL_END
