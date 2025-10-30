#import "SentryDefaultUIViewControllerPerformanceTracker.h"
#import "SentryHub+Private.h"
#import "SentryPerformanceTracker.h"
#import "SentryTracer.h"

@class SentryTimeToDisplayTracker;

@interface SentryPerformanceTracker ()
- (void)clear;
@end
