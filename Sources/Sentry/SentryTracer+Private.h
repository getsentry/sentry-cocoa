#import "SentryTracer.h"

@interface
SentryTracer ()

/**
 * When an app launch is traced, after building the app start spans, the tracer's start timestamp is
 * adjusted backwards to be the start of the first app start span. But, we still need to know the
 * real start time of the trace for other purposes. This property provides a place to keep it before
 * reassigning it.
 */
@property (strong, nonatomic) NSDate *originalStartTimestamp;

@property (assign, nonatomic) BOOL startTimeChanged;

@end
