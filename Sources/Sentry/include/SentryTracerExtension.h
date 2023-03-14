#import "SentrySpan.h"
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

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

@end

NS_ASSUME_NONNULL_END
