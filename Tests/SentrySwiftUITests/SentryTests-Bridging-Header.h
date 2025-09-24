#import "SentryHub+Private.h"
#import "SentryTracer.h"
#import "SentryUIViewControllerPerformanceTracker.h"

@class SentryTimeToDisplayTracker;

@interface SentryUIViewControllerPerformanceTracker ()
@property (nullable, nonatomic, weak) SentryTimeToDisplayTracker *currentTTDTracker;
@end
