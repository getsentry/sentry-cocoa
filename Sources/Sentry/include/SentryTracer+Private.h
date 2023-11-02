#import "SentryTracer.h"

@interface
SentryTracer ()

@property (nonatomic, strong) SentryHub *hub;

/**
 * We need an unchanging identifier to track concurrent tracers against a static profiler.
 * @c SentryTracer.traceId can be changed by consumers so is unfit for this purpose.
 */
@property (nonatomic, strong) SentryId *concurrencyID;

@end
